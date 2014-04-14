require 'app_conf'
require 'hipchat'

class Chef
  class Knife
    module NitrousBase

      def self.included(includer)
        includer.class_eval do
          deps do
            require 'active_support/all'
            require 'chef/json_compat'
            require 'chef/knife/bootstrap'
            require 'chef/knife/ssh'

            require 'yaml'
            require 'ipaddress'
            require 'domainatrix'
            require 'fog'
            require 'mixins/aws'
            require 'categories/security_group+nitrous'
            require 'security_groups/security_rule'
            require 'security_groups/security_group'
            require 'security_groups/security_groups'
            require 'block_devices/block_device'
            require 'block_devices/block_device_collection'
            require 'servers/server'
            require 'servers/server_collection'

            Chef::Knife::Ssh.load_deps
            Chef::Knife::Bootstrap.load_deps
            Chef::Knife::SoloBootstrap.load_deps if defined? Chef::Knife::SoloBootstrap
          end
        end
      end

      def provision_security_group!(servers, security_group_hash)
        return unless servers.respond_to?(:map)

        regions = servers.map(&:region).uniq.sort
        regions.each do |r|
          KnifeNitrous::SecurityGroups.from_hash(security_group_hash).to_a.each do |sg|
            sg.provision(r)
          end
        end
      end

      def bootstrap_chef_for_node(server)
        bootstrap = bootstrap_class.new
        bootstrap.name_args = [server.aws_dns_name]
        bootstrap.config[:run_list] = server.run_list
        bootstrap.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        bootstrap.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        bootstrap.config[:identity_file] = identity_file(server.region)

        bootstrap.config[:chef_node_name] = server.hostname
        bootstrap.config[:first_boot_attributes] = server.attributes || {}

        bootstrap.config[:distro] = "chef-full"
        bootstrap.config[:use_sudo] = true

        bootstrap.config[:host_key_verify] = false if solo_bootstrap?

        # Do some cleanup before we proceed:
        clean_node_directory if solo_bootstrap?

        # Modify global configuration state to ensure hint gets set by
        # knife-bootstrap
        Chef::Config[:knife][:hints] ||= {}
        Chef::Config[:knife][:hints]["ec2"] ||= {}
        bootstrap
      end

      def chef_runner_for_node(server, timestamp, solo_conf={})
        ssh = solo_bootstrap? ? Chef::Knife::SoloCook.new : Chef::Knife::Ssh.new
        ssh.ui = ui

        att_file_name = attributes_file_name(server.type, timestamp)

        clean_node_directory if solo_bootstrap?

        ssh.name_args = if solo_bootstrap?
          [ server.hostname ]
        else
          [ server.aws_dns_name, "sudo chef-client -c /etc/chef/client.rb -j #{att_file_name}" ]
        end

        if solo_bootstrap?
          ssh.config[:run_list] = server.run_list
          ssh.config[:json_attributes] = server.attributes
          ssh.config[:host_key_verify] = false
          ssh.config[:chef_node_name] = server.hostname
          ssh.config[:override_runlist] = solo_conf[:override_runlist] if solo_conf[:override_runlist]
        end

        ssh.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        ssh.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        ssh.config[:identity_file] = identity_file(server.region)
        ssh.config[:manual] = true
        ssh.config[:on_error] = :raise

        ssh
      end

      def chef_attributes_loader_for_node(server, timestamp)
        ssh = Chef::Knife::Ssh.new
        ssh.ui = ui

        att_file_name = attributes_file_name(server.type, timestamp)
        json_attributes = server.attributes

        command = "sudo /opt/chef/embedded/bin/ruby -e \"require 'json'; File.open('#{att_file_name}', 'w') { |f| f.puts('#{json_attributes.to_json.gsub(/"/, '\\"')}') }\""

        ssh.name_args = [ server.hostname, command ]
        ssh.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        ssh.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        ssh.config[:identity_file] = identity_file(server.region)
        ssh.config[:manual] = true
        ssh.config[:on_error] = :raise

        ssh
      end

      def bootstrap_class
        solo_bootstrap? ? Chef::Knife::SoloBootstrap : Chef::Knife::Bootstrap
      end

      def solo_bootstrap?
        config[:solo] || (config[:solo].nil? && Chef::Config[:knife][:solo])
      end

      def clean_node_directory
        if Chef::Config[:node_path].nil?
          puts "node_path is not set - please set this to 'nodes' in your knife.rb file."
          return true
        else
          FileUtils.rm(Dir.glob("#{Chef::Config[:node_path]}/*.json"))
        end
      end

      def nitrous_config
        return @nitrous_config if @nitrous_config

        @nitrous_config = AppConf.new
        load_paths = [File.expand_path('~/.chef/nitrous.yml'), File.expand_path('./nitrous.yml')]
        load_paths.each do |load_path|
          if File.exists?(load_path)
            @nitrous_config.load(load_path)
          end
        end

        @nitrous_config
      end

      protected
      def attributes_file_name(name, timestamp)
        File.join("/", "tmp", "#{name}-#{timestamp}.json")
      end

      # An "instance-global" identifier for a single run of a knife subcommand.
      def run_id
        @run_id ||= "#{ENV['USER']}@#{Time.now.utc.strftime('%d-%b-%Y-%H-%M')}"
      end

      def announce(message, level: :info)
        term_color, hipchat_color = case level
        when :error, :warn
          [:red, 'red']
        when :success
          [:green, 'green']
        when :info
          [:magenta, 'yellow']
        else
          [:magenta, 'yellow']
        end

        puts "===> #{ui.color(message, term_color)}"
        if hipchat_enabled?
          token = case level
          when :error, :warn
            '(ಠ_ಠ)'
          when :success
            '✌(-‿-)✌'
          else
            '(⌐■_■)'
          end
          hipchat_room.send('knife-nitrous', "#{message} #{token}", color: hipchat_color, message_format: 'text')
        end
      end

      def hipchat_enabled?
        nitrous_config.hipchat && nitrous_config.hipchat[:enabled]
      end

      def hipchat_client
        @hipchat_client ||= HipChat::Client.new(nitrous_config.hipchat[:key], api_version: 'v1')
      end

      def hipchat_room
        @hipchat_room ||= hipchat_client[nitrous_config.hipchat[:room]]
      end

      # get correct identity file. Here are where we will look for the new file
      # - $HOME/.ec2/nitrous.pem
      # - $HOME/.ec2/#{region}-keypair.pem
      def identity_file(region=nil)
        locations = ["#{ENV['HOME']}/.ec2/nitrous.pem"]
        locations << "#{ENV['HOME']}/.ec2/#{region}-keypair.pem" if region
        locations.find { |l| File.exists?(l) }
      end
    end
  end
end
