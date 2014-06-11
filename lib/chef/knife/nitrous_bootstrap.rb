module KnifeNitrous
  class NitrousBootstrap < Chef::Knife

    require 'chef/knife/nitrous_base'
    include Chef::Knife::NitrousBase

    banner    'knife nitrous bootstrap (options)'
    category  'nitrous'

    option :yaml_file,
      short: "-F FILE",
      long: "--yaml_file FILE",
      description: "YAML file definition for servers."

    option :sg_directory,
      short: "-S DIRECTORY",
      long: "--sg_yaml DIRECTORY",
      description: "Directory containing security groups in YAML format."

    option :region,
      short: "-r REGION",
      long: "--region REGION",
      description: "The region you want to run chef in"

    option :hostname,
      short: "-h HOSTNAME",
      long: "--hostname HOSTNAME",
      description: "The host you want to run chef in"

    option :solo,
      long: '--[no-]solo',
      description: 'Do a chef-solo bootstrap on the droplet using knife-solo',
      proc: Proc.new { |s| Chef::Config[:knife][:solo] = s }

    attr_reader :name, :server_collection

    def run
      if config[:yaml_file].nil?
        ui.error("You have not provided a YAML server config file (-F).")
        exit 1
      end

      if config[:sg_directory].nil?
        ui.error("You have not provided a directory containing security group YAML files (-S).")
        exit 1
      end

      @server_collection = KnifeNitrous::ServerCollection.parse(config[:yaml_file], config[:sg_directory])
      servers_to_provision = @server_collection.to_a

      if config[:region].present?
        servers_to_provision.select! { |s| config[:region].include?(s.region) }
      elsif config[:hostname]
        servers_to_provision.select! { |s| config[:hostname] == s.hostname }
      end

      self.provision_security_group! servers_to_provision, server_collection.security_group_hash

      announce("#{ENV['USER']} is bootstrapping #{servers_to_provision.count} server(s): #{servers_to_provision.map(&:hostname).join(',')}")
      servers_to_provision.each do |s|
        if s.cloud_state == 'running'
          s.setup_volumes

          announce("Bootstrap started on #{s.hostname}")
          bootstrap_chef_for_node(s).run
          announce("Bootstrap completed on #{s.hostname}", level: :success)
        else
          announce("Bootstrap skipped on #{s.hostname}, state: #{s.cloud_state}", level: :warn)
        end
      end
    end

  end
end
