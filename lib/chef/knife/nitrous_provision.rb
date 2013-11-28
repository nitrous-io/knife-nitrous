module KnifeNitrous
  class NitrousProvision < Chef::Knife
    include Chef::Knife::NitrousBase

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

    option :yaml_file,
      short: "-F FILE",
      long: "--yaml_file FILE",
      description: "YAML file definition for servers."

    option :sg_directory,
      short: "-S DIRECTORY",
      long: "--sg_yaml DIRECTORY",
      description: "Directory containing security groups in YAML format."

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

      self.provision_security_group! servers_to_provision, server_collection.security_group_hash

      servers_to_provision.each do |s|
        timestamp = Time.now.to_i

        if s.cloud_state == 'running'
          s.setup_volumes

          chef_attributes_loader_for_node(s, timestamp).run
          chef_runner_for_node(s, timestamp).run
        end
      end
    end
  end
end

