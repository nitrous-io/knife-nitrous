module KnifeNitrous
  class NitrousCreate < Chef::Knife

    deps do
      require 'chef/json_compat'
      require 'chef/knife/bootstrap'
      require 'mixins/aws'
      require 'security_groups/security_rule'
      require 'security_groups/security_group'
      require 'servers/server'
      require 'servers/server_collection'

      Chef::Knife::Bootstrap.load_deps
    end

    banner    'knife nitrous create (options)'
    category  'nitrous'

    attr_reader :name, :server_collection

    def run
      @server_collection = KnifeNitrous::ServerCollection.parse
      server_collection.provision_security_group!

      server_collection.each do |s|
        s.provision && self.bootstrap_chef_for_node(s)
      end
    end

    def bootstrap_chef_for_node(server)
      bootstrap = Chef::Knife::Bootstrap.new
      bootstrap.name_args = [server.hostname]
      bootstrap.config[:run_list] = "recipe[#{server.type}]"
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

    protected
    def locate_config_value(key)
      key = key.to_sym
      config[key] || Chef::Config[:knife][key]
    end
  end
end

