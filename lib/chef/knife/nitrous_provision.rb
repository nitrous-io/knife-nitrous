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

    attr_reader :name, :server_collection

    def run
      @server_collection = KnifeNitrous::ServerCollection.parse
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

