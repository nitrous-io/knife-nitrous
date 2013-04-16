module KnifeNitrous
  class NitrousCreate < Chef::Knife

    include Chef::Knife::NitrousBase

    banner    'knife nitrous create'
    category  'nitrous'

    attr_reader :name, :server_collection

    def run
      @server_collection = KnifeNitrous::ServerCollection.parse
      server_collection.provision_security_group!

      server_collection.each do |s|
        if s.cloud_state == 'terminated'
          s.provision
          self.bootstrap_chef_for_node(s).run
        end
      end
    end
  end
end

