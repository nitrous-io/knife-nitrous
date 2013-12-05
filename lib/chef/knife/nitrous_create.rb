module KnifeNitrous
  class NitrousCreate < Chef::Knife

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
      description: "Directory containing security groups in YAML format."

    option :solo,
      :long        => '--[no-]solo',
      :description => 'Do a chef-solo bootstrap on the droplet using knife-solo',
      :proc        => Proc.new { |s| Chef::Config[:knife][:solo] = s }

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

      if solo_bootstrap? && !defined?(Chef::Knife::SoloBootstrap)
        ui.error [
          'Knife plugin knife-solo was not found.',
          'Please add the knife-solo gem to your Gemfile or',
          'install it manually with `gem install knife-solo`.'
        ].join(" ")
        exit 1
      end

      puts "===> " + ui.color("Parsing ServerCollection from #{config[:yaml_file]} and security group directory #{config[:sg_directory]}", :magenta)
      @server_collection = KnifeNitrous::ServerCollection.parse(config[:yaml_file], config[:sg_directory])

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

