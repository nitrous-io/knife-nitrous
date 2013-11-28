module KnifeNitrous
  class SecurityGroup
    include KnifeNitrous::AWS

    attr_accessor :name
    attr_reader :region

    def initialize(name)
      self.name = name
      @rules = Set.new
    end

    def add_rule(rule)
      @rules.add rule
    end

    def eql?(group)
      self.name.eql?(group.name) &&
      self.rules.eql?(group.rules)
    end

    def hash
      [self.name, self.rules].hash
    end

    def provision(region)
      @region  = region

      security_group = compute.security_groups.get(self.name) ||
                       compute.security_groups.create(name: self.name,
                                                      description: self.name).reload
      security_group.sync(@rules)
    end

    def rules
      @rules.to_a
    end

    def self.from_hash(hash)
      name = hash.keys.first
      security_group = KnifeNitrous::SecurityGroup.new(name)
      hash['name']['rules'].each { |r| security_group.add_rule KnifeNitrous::SecurityRule.parse(r) }
      security_group
    end
  end
end
