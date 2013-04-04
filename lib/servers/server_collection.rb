module KnifeNitrous
  class ServerCollection

    attr_accessor :current_region, :environment
    attr_reader   :regions, :security_group

    def initialize(security_group_hash)
      @servers, @regions = [], []
      @security_group = KnifeNitrous::SecurityGroup.from_hash(security_group_hash)
    end

    def add(server)
      @servers.push server
    end

    def provision
      @regions.each { |r| @security_group.provision(r) }

      @servers.select do |s|
        @regions.include?(s.region)
      end.each { |s| s.provision }
    end

    def set_region(region)
      all_regions = @servers.map(&:region).uniq.sort
      region_is_set = false

      if all_regions.count > 1
        if region == 'all'
          @regions = all_regions
          region_is_set = true
        else
          unless all_regions.index(region).nil?
            @regions.push region
            region_is_set = true
          end
        end
      else
        @regions.push regions.first
        region_is_set = true
      end

      return region_is_set
    end

    def find_by_hostname(hostname)
      @servers.find { |s| s.hostname == hostname }
    end

    def size; @servers.size; end

    def to_a; @servers; end

    def self.parse
      config_file = 'nitrous.json'
      parsed_json = nil

      return nil if !File.exists? config_file

      begin
        parsed_json = JSON.parse(File.read(config_file))
      rescue JSON::ParserError
        return nil
      end

      server_collection = self.new(parsed_json['security_group'])

      parsed_json['servers'].each do |server_config|
        server = KnifeNitrous::Server.new(hostname: server_config['hostname'],
                                          size: server_config['size'],
                                          ami: server_config['ami'],
                                          region: server_config['region'],
                                          elb: server_config['elb'] || false)
        server.block_devices = KnifeNitrous::BlockDeviceCollection.new(server_config['block_devices'])

        server_collection.add server
      end

      server_collection
    end
  end
end
