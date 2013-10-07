module KnifeNitrous
  class NitrousCreate < Chef::Knife

    include Chef::Knife::NitrousBase

    banner    'knife nitrous create'
    category  'nitrous'

    attr_reader :name, :server_collection

    def run
      puts "===> " + ui.color('Parsing ServerCollection from nitrous.json', :magenta)
      @server_collection = KnifeNitrous::ServerCollection.parse

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

