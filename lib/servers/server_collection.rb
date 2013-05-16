module KnifeNitrous
  class ServerCollection

    attr_accessor :current_region, :environment
    attr_reader   :regions, :security_group, :type

    def initialize(type, security_group_hash)
      @servers, @regions = [], []

      @type = type
      @security_group = KnifeNitrous::SecurityGroup.from_hash(security_group_hash)
    end

    def add(server)
      @servers.push server
    end

    def provision_security_group!
      @regions = @servers.map(&:region).uniq.sort
      @regions.each { |r| @security_group.provision(r) }
    end

    def each(&block); @servers.each { |s| yield(s) }; end

    def size; @servers.size; end

    def to_a; @servers; end

    def self.parse
      config_file = 'nitrous.json'
      parsed_json = nil

      return nil if !File.exists? config_file

      begin
        parsed_json = JSON.parse(File.read(config_file))
      rescue JSON::ParserError
        p "Failed to parse nitrous.json config file"
        return nil
      end

      server_collection = self.new(parsed_json['type'],
                                   parsed_json['security_group'].merge!('name' => parsed_json['type']))

      parsed_json['servers'].each do |server_config|
        server = KnifeNitrous::Server.new(hostname: server_config['hostname'],
                                          size: server_config['size'],
                                          ami: server_config['ami'],
                                          region: server_config['region'],
                                          type: parsed_json['type'],
                                          attributes: server_config['attributes'],
                                          cookbook: parsed_json['cookbook'])

        server.block_devices = KnifeNitrous::BlockDeviceCollection.new(server_config['block_devices'])

        server_collection.add server
      end

      server_collection
    end
  end
end
