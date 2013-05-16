module KnifeNitrous
  class NitrousSetupVolumes < Chef::Knife
    include Chef::Knife::NitrousBase

    banner    'knife nitrous resize_volumes (options)'
    category  'nitrous'

    option :hostname,
      short: "-h HOSTNAME",
      long: "--hostname HOSTNAME",
      description: "The host you want to run chef in"

    attr_reader :name, :server_collection

    def run
      raise "Required hostname to be set" unless config[:hostname].present?

      @server_collection = KnifeNitrous::ServerCollection.parse
      server_array = @server_collection.to_a
      servers_to_provision = server_array

      servers_to_provision = server_array.select do |s|
        config[:hostname] == s.hostname
      end

      servers_to_provision.each do |s|
        s.setup_volumes if s.cloud_state == "running"
      end
    end
  end
end
