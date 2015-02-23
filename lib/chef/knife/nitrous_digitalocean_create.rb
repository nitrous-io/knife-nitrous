module KnifeNitrous
  class DigitalOceanCreate < Chef::Knife
    require 'chef/knife/nitrous_digitalocean_base'
    include Chef::Knife::NitrousDigitalOceanBase

    deps do
      require 'socket'
      require 'chef/knife/bootstrap'
      Chef::Knife::Bootstrap.load_deps
      Chef::Knife::NitrousDigitalOceanBase.load_deps
      # Knife loads subcommands automatically, so we can just check if the
      # class exists.
      Chef::Knife::SoloBootstrap.load_deps if defined? Chef::Knife::SoloBootstrap
    end

    banner 'knife nitrous digitaloceancreate (options)'
    category  'nitrous'

    option :yaml_file,
      short: "-F FILE",
      long: "--yaml_file FILE",
      description: "YAML file definition for servers."

    option :solo,
      long: '--[no-]solo',
      description: 'Do a chef-solo bootstrap on the droplet using knife-solo',
      proc: Proc.new { |s| Chef::Config[:knife][:solo] = s }

    def run
      validate!

      if config[:yaml_file].nil? || !File.exists?(config[:yaml_file])
        ui.error("You have not provided a YAML server config file (-F).")
        exit 1
      end


      if solo_bootstrap? && !defined?(Chef::Knife::SoloBootstrap)
        ui.error [
          'Knife plugin knife-solo was not found.',
          'Please add the knife-solo gem to your Gemfile or',
          'install it manually with `gem install knife-solo`.'
        ].join(' ')
        exit 1
      end

      ssh_key_ids = []
      client.ssh_keys.all.each do |key|
        ssh_key_ids<<key.id 
      end

      droplet_conf = parse(config[:yaml_file])

      droplet = DropletKit::Droplet.new(name: droplet_conf.name,
                                        size: droplet_conf.size,
                                        region: droplet_conf.region,
                                        ssh_keys: ssh_key_ids)

      server = client.droplets.create(droplet)

      if client.droplets.find(id: server.id).status != 'new'
        ui.error("Droplet could not be started #{server.inspect}")
        exit 1
      end

      puts "Droplet creation for #{locate_config_value(:server_name)} started. Droplet-ID is #{server.id}"

      unless !config.key?(:json_attributes) || config[:json_attributes].empty?
        puts ui.color("JSON Attributes: #{config[:json_attributes]}", :magenta)
      end

      print ui.color('Waiting for IPv4-Address', :magenta)
      print('.') until ip_address = ip_address_available(server.id) do
        puts 'done'
      end

      puts ui.color("IPv4 address is: #{ip_address}", :green)

      print ui.color('Waiting for sshd:', :magenta)
      print('.') until tcp_test_ssh(ip_address) do
        sleep 2
        puts 'done'
      end

      if solo_bootstrap?
        bootstrap_for_node(droplet_conf, ip_address).run
      else
        puts ip_address
        exit 0
      end
    end

    def ip_address_available(droplet_id)
      server = client.droplets.find(id: droplet_id)
      if server.public_ip
        yield
        server.public_ip
      else
        sleep @initial_sleep_delay ||= 10
        false
      end
    end

    def tcp_test_ssh(hostname)
      port = Chef::Config[:knife][:ssh_port] || config[:ssh_port]
      tcp_socket = TCPSocket.new(hostname, port)
      readable = IO.select([tcp_socket], nil, nil, 5)
      if readable
        Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
        yield
        true
      else
        false
      end
    rescue Errno::ETIMEDOUT
      false
    rescue Errno::EPERM
      false
    rescue Errno::ECONNREFUSED
      sleep 2
      false
    rescue Errno::EHOSTUNREACH
      sleep 2
      false
    ensure
      tcp_socket && tcp_socket.close
    end

    def solo_bootstrap?
      config[:solo] || (config[:solo].nil? && Chef::Config[:knife][:solo])
    end
  end
end
