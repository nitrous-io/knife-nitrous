module KnifeNitrous
  class NitrousProvision < Chef::Knife
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
    end

    banner    'knife nitrous provision (options)'
    category  'nitrous'

    option :region,
      short: "-r REGION",
      long: "--region REGION",
      description: "The region you want to run chef in"

    option :hostname,
      short: "-h HOSTNAME",
      long: "--hostname HOSTNAME",
      description: "The host you want to run chef in"

    attr_reader :name, :server_collection

    def run
      @server_collection = KnifeNitrous::ServerCollection.parse
      server_array = @server_collection.to_a
      servers_to_provision = server_array

      if config[:region].present?
        servers_to_provision = server_array.select do |s|
          config[:region].include?(s.region)
        end
      elsif config[:hostname]
        servers_to_provision = server_array.select do |s|
          config[:hostname] == s.hostname
        end
      end

      servers_to_provision.each do |s|
        chef_runner_for_node(s).run if s.cloud_state == 'running'
      end
    end

    def chef_runner_for_node(server)
      ssh = Chef::Knife::Ssh.new
      ssh.ui = ui

      ssh.name_args = [ server.hostname, "sudo chef-client -c /etc/chef/client.rb" ]
      ssh.config[:ssh_user] = KnifeNitrous::Server::SSH_USER
      ssh.config[:ssh_port] = KnifeNitrous::Server::SSH_PORT
      ssh.config[:identity_file] = "~/.ec2/#{server.region}-keypair.pem"
      ssh.config[:manual] = true
      ssh.config[:on_error] = :raise

      ssh
    end
  end
end

