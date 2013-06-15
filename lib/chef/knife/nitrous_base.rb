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

            require 'ipaddress'
            require 'domainatrix'
            require 'fog'
            require 'mixins/aws'
            require 'categories/security_group+nitrous'
            require 'security_groups/security_rule'
            require 'security_groups/security_group'
            require 'block_devices/block_device'
            require 'block_devices/block_device_collection'
            require 'servers/server'
            require 'servers/server_collection'

            Chef::Knife::Ssh.load_deps
            Chef::Knife::Bootstrap.load_deps
          end
        end
      end

      def bootstrap_chef_for_node(server)
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [server.aws_dns_name]
        bootstrap.config[:run_list] = "recipe[#{server.cookbook}]"
        bootstrap.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        bootstrap.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        bootstrap.config[:identity_file] = "~/.ec2/#{server.region}-keypair.pem"

        bootstrap.config[:chef_node_name] = server.hostname
        bootstrap.config[:first_boot_attributes] = server.attributes || {}

        bootstrap.config[:distro] = "chef-full"
        bootstrap.config[:use_sudo] = true

        # Modify global configuration state to ensure hint gets set by
        # knife-bootstrap
        Chef::Config[:knife][:hints] ||= {}
        Chef::Config[:knife][:hints]["ec2"] ||= {}
        bootstrap
      end

      def chef_runner_for_node(server, timestamp)
        ssh = Chef::Knife::Ssh.new
        ssh.ui = ui

        att_file_name = attributes_file_name(server.type, timestamp)

        ssh.name_args = [ server.aws_dns_name, "sudo chef-client -c /etc/chef/client.rb -j #{att_file_name}" ]
        ssh.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
        ssh.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
        ssh.config[:identity_file] = "~/.ec2/#{server.region}-keypair.pem"
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
        ssh.config[:identity_file] = "~/.ec2/#{server.region}-keypair.pem"
        ssh.config[:manual] = true
        ssh.config[:on_error] = :raise

        ssh
      end

      protected
      def attributes_file_name(name, timestamp)
        File.join("/", "tmp", "#{name}-#{timestamp}.json")
      end
    end
  end
end

