module KnifeNitrous
  class NitrousCreate < Chef::Knife

    require 'chef/knife/nitrous_base'
    include Chef::Knife::NitrousBase

    banner    'knife nitrous create'
    category  'nitrous'

    option :yaml_file,
      short: "-F FILE",
      long: "--yaml_file FILE",
      description: "YAML file definition for servers."

    option :sg_directory,
      short: "-S DIRECTORY",
      long: "--sg_yaml DIRECTORY",
      description: "Directory containing security groups in YAML format.",
      default: 'security_groups'

    option :user_data,
      short: "-U USER_DATA_FILE",
      long: "--user-data USER_DATA_FILE",
      description: "Cloud Init file which contains cloud-init config"

    option :solo,
      long: '--[no-]solo',
      description: 'Do a chef-solo bootstrap on the droplet using knife-solo',
      proc: Proc.new { |s| Chef::Config[:knife][:solo] = s }

    attr_reader :name, :server_collection

    def run
      # TODO: Make this a required option in the option :yaml_file block above, but
      # couldnt' figure out a way to test easily
      if config[:yaml_file].nil? || !File.exists?(config[:yaml_file])
        ui.error("You have not provided a YAML server config file (-F).")
        exit 1
      end

      # TODO: Make this a default: 'security_groups' option in the option for sg_directory
      # but couldn't figure out a way to test easily
      config[:sg_directory] ||= 'security_groups'
      unless File.exists?(config[:sg_directory])
        ui.error("You have not provided a directory containing security group YAML files (-S).")
        exit 1
      end

      # TODO: Make this a default: 'cloud_init/init.txt' option in the option for sg_directory
      # but couldn't figure out a way to test easily
      config[:user_data] ||= File.expand_path("user_data/init.txt")
      unless File.exists?(config[:user_data])
        ui.error("You have not provided a user-data file")
        exit 1
      end

      @server_collection = KnifeNitrous::ServerCollection.parse(config[:yaml_file],
                                                                config[:sg_directory],
                                                                user_data: File.read(config[:user_data]))

      puts "===> " + ui.color("Provisioning Security Groups")
      self.provision_security_group! server_collection, server_collection.security_group_hash

      server_collection.each do |s|
        if s.cloud_state == 'terminated'
          puts "===> " + ui.color("Provisioning Server: #{s.hostname}", :magenta)
          s.provision
          puts "===> " + ui.color("Bootstrapping Chef on Server: #{s.hostname}", :magenta)
          self.bootstrap_chef_for_node(s).run
        end
      end
    end
  end
end
