module KnifeNitrous
  class NitrousProvision < Chef::Knife
    require 'chef/knife/nitrous_base'
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

    option :override_runlist,
      short: '-o RunlistItem,RunlistItem...,',
      long: '--override-runlist',
      description: 'Replace current run list with specified items'

    option :json_attribs,
      :short => "-j JSON_ATTRIBS",
      :long => "--json-attributes JSON_ATTRIBS",
      :description => "Load attributes from a JSON file"

    option :solo,
      long: '--[no-]solo',
      description: 'Do a chef-solo bootstrap on the droplet using knife-solo',
      proc: Proc.new { |s| Chef::Config[:knife][:solo] = s }

    option :setup,
      long: "--[no-]setup",
      description: "Perform additional infrastructure setup using EC2 API",
      boolean: true,
      default: true

    option :ssh_port,
      short: "-p SSH_PORT",
      description: "speicify a custom ssh port"

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

      if config[:setup]
        @server_collection = KnifeNitrous::ServerCollection.parse(config[:yaml_file], config[:sg_directory])
        servers_to_provision = @server_collection.to_a
      else
        @server_collection = KnifeNitrous::PlainServerCollection.parse(config[:yaml_file])
        servers_to_provision = @server_collection.to_a
      end

      if config[:region].present?
        servers_to_provision.select! { |s| config[:region].include?(s.region) }
      elsif config[:hostname]
        servers_to_provision.select! { |s| config[:hostname] == s.hostname }
      end

      if config[:setup]
        self.provision_security_group! servers_to_provision, server_collection.security_group_hash
      end

      solo_conf = {}
      if config[:override_runlist].present?
        solo_conf[:override_runlist] = config[:override_runlist]
      end

      if config[:json_attribs].present?
        override_json = File.read(config[:json_attribs])
        override_hash = JSON.parse(override_json)
      end

      announce("#{ENV['USER']} is provisioning: #{servers_to_provision.map(&:hostname).join(',')}")
      servers_to_provision.each_with_index do |s, i|
        puts "===> " + ui.color("Server ##{i+1} of #{servers_to_provision.count}: #{s.hostname}", :green)
        timestamp = Time.now.to_i
        if override_hash.is_a?(Hash)
          s.attributes = s.attributes.deep_merge(override_hash)
        end
        run_list = config[:override_runlist].present? ? "[#{config[:override_runlist]}] (overridden)" : s.run_list

        if config[:setup]
          if s.cloud_state == 'running'
            s.setup_volumes
            chef_attributes_loader_for_node(s, timestamp, config[:ssh_port]).run
            chef_runner = chef_runner_for_node(s, timestamp, solo_conf, config[:ssh_port])
            begin
              chef_runner.run
            rescue => e
              announce("Failed provisioning on #{s.hostname}. Run list: #{run_list}", level: :error)
              raise e
            end
            announce("Completed provisioning on #{s.hostname}. Run list: #{run_list}", level: :success)
          else
            announce("Skipped provisioning on #{s.hostname}, state: #{s.cloud_state}", level: :warn)
          end
        else
          chef_attributes_loader_for_node(s, timestamp, config[:ssh_port]).run
          chef_runner = chef_runner_for_node(s, timestamp, solo_conf, config[:ssh_port])
          begin
            chef_runner.run
          rescue => e
            announce("Failed provisioning on #{s.hostname}. Run list: #{run_list}", level: :error)
            raise e
          end
          announce("Completed provisioning on #{s.hostname}. Run list: #{run_list}", level: :success)
        end
      end
    end
  end
end
