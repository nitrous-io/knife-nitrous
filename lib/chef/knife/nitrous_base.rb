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
        bootstrap.config[:identity_file] = "#{ENV['HOME']}/.ec2/#{server.region}-keypair.pem"

        bootstrap.config[:chef_node_name] = server.hostname
        bootstrap.config[:first_boot_attributes] = server.attributes || {}

        bootstrap.config[:distro] = "chef-full"
        bootstrap.config[:use_sudo] = true

        # Do some cleanup before we proceed:
        clean_node_directory if solo_bootstrap?
        remove_host_key_entry(server.aws_dns_name)

        # Modify global configuration state to ensure hint gets set by
        # knife-bootstrap
        Chef::Config[:knife][:hints] ||= {}
        Chef::Config[:knife][:hints]["ec2"] ||= {}
        bootstrap
      end

      def chef_runner_for_node(server, timestamp)
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
        end

        ssh.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        ssh.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        ssh.config[:identity_file] = "#{ENV['HOME']}/.ec2/#{server.region}-keypair.pem"
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
        ssh.config[:identity_file] = "#{ENV['HOME']}/.ec2/#{server.region}-keypair.pem"
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
        FileUtils.rm_rf(Dir.glob("#{Chef::Config[:node_path]}/*"))
      end

      def remove_host_key_entry(hostname)
        ip = Resolv.getaddress(hostname)

        ssh_keygen_hostname = "[#{hostname}]:#{KnifeNitrous::Server::SSH_PORT}"
        ssh_keygen_ip       = "[#{ip}]:#{KnifeNitrous::Server::SSH_PORT}"

        puts "Removing host key entries #{ssh_keygen_hostname} and #{ssh_keygen_ip}. Backup created in ~/.ssh/known_hosts.old."

        system("ssh-keygen -R '#{ssh_keygen_hostname}' >/dev/null")
        system("ssh-keygen -R '#{ssh_keygen_ip}' >/dev/null")
      end

      protected
      def attributes_file_name(name, timestamp)
        File.join("/", "tmp", "#{name}-#{timestamp}.json")
      end
    end
  end
end

