module KnifeNitrous
  class ServerCollection

    attr_accessor :current_region, :environment
    attr_reader   :regions, :security_group_hash, :type

    def initialize(type, security_group_hash)
      @servers, @regions = [], []

      @type = type
      @security_group_hash = security_group_hash
    end

    def add(server)
      @servers.push server
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
        p "Invalid JSON. Check your nitrous.json file."
        return nil
      end

      server_collection = self.new(parsed_json['type'],
                                   parsed_json['security_group'].merge!('name' => parsed_json['type']))

      parsed_json['servers'].each do |server_config|
        if parsed_json["servers_common"]
          server_config = deep_merge parsed_json["servers_common"], server_config
        end
        server = KnifeNitrous::Server.new(hostname: server_config['hostname'],
                                          size: server_config['size'],
                                          ami: server_config['ami'],
                                          region: server_config['region'],
                                          type: parsed_json['type'],
                                          attributes: server_config['attributes'],
                                          cookbook: parsed_json['cookbook'],
                                          availability_zone: server_config['availability_zone'])

        server.block_devices = KnifeNitrous::BlockDeviceCollection.new(server_config['block_devices'])

        server_collection.add server
      end

      server_collection
    end

    # deep merge changes from other_hash to hash, returns a copy of hash
    def self.deep_merge(hash, other_hash)
      dhash = hash.dup
      other_hash.each_pair do |k,v|
        tv = dhash[k]
        if tv.is_a?(Hash) && v.is_a?(Hash)
          dhash[k] = deep_merge(tv, v)
        else
          dhash[k] = v
        end
      end
      dhash
    end
  end
end
