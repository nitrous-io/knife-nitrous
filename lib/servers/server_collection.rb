module KnifeNitrous
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

  class PlainServerCollection
    attr_reader   :regions, :type

    def initialize(type)
      @servers, @regions = [], []
      @type = type
    end

    def add(server); @servers.push server; end
    def map(&block) ; @servers.map { |s| yield(s) }; end
    def each(&block); @servers.each { |s| yield(s) }; end
    def size; @servers.size; end
    def to_a; @servers; end

    def self.parse(config_file)
      return nil unless File.exists? config_file
      parsed_yaml = nil
      begin
        parsed_yaml = YAML.load(File.read(config_file))
      rescue Psych::SyntaxError
        p "Invalid YAML. Check your #{config_file} file."
        return nil
      end

      server_collection = self.new(parsed_yaml['type'])
      parsed_yaml['servers'].each do |server_config|
        if parsed_yaml["servers_common"]
          server_config = KnifeNitrous.deep_merge parsed_yaml["servers_common"], server_config
        end
        server = KnifeNitrous::PlainServer.new(
          hostname: server_config['hostname'],
          region: server_config['region'],
          attributes: server_config['attributes'],
          run_list: parsed_yaml['run_list'],
          type: parsed_yaml['type'],
        )
        server_collection.add server
      end
      server_collection
    end
  end

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

    def map(&block) ; @servers.map { |s| yield(s) }; end

    def each(&block); @servers.each { |s| yield(s) }; end

    def size; @servers.size; end

    def to_a; @servers; end

    def self.parse(config_file, security_group_directory, opts = {})
      return nil unless File.exists? config_file

      parsed_yaml = nil

      begin
        parsed_yaml = YAML.load(File.read(config_file))
      rescue Psych::SyntaxError
        p "Invalid YAML. Check your #{config_file} file."
        return nil
      end

      user_data = opts[:user_data]

      # Load in security groups from the specified directory.
      security_groups = {}
      Dir.glob("#{security_group_directory}/**/*").each do |file|
        begin
          yaml = YAML.load(File.read(file))
          security_groups.merge!(yaml)
        rescue Psych::SyntaxError
          p "Invalid YAML. Check your #{file} file."
          return nil
        end
      end

      # Filter out security groups that are not specified in the
      # server YAML file.
      security_groups = security_groups.select do |x|
        parsed_yaml['security_groups'].include?(x)
      end

      server_collection = self.new(parsed_yaml['type'], security_groups)

      parsed_yaml['servers'].each do |server_config|
        if parsed_yaml["servers_common"]
          server_config = KnifeNitrous.deep_merge parsed_yaml["servers_common"], server_config
        end
        server = KnifeNitrous::Server.new(hostname: server_config['hostname'],
                                          size: server_config['size'],
                                          ami: server_config['ami'],
                                          region: server_config['region'],
                                          type: parsed_yaml['type'],
                                          attributes: server_config['attributes'],
                                          iam_role: parsed_yaml['iam_role'],
                                          security_groups: security_groups.keys,
                                          run_list: parsed_yaml['run_list'],
                                          availability_zone: server_config['availability_zone'])

        server.user_data = user_data unless user_data.nil?
        server.block_devices = KnifeNitrous::BlockDeviceCollection.new(server_config['block_devices'])

        server_collection.add server
      end

      server_collection
    end
  end
end
