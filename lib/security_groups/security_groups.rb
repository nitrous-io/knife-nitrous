module KnifeNitrous
  class SecurityGroups
    include KnifeNitrous::AWS

    # @groups is an array of KnifeNitrous::SecurityGroup objects.
    attr_accessor :groups

    def initialize(groups)
      self.groups = groups
    end

    def to_a
      self.groups
    end

    def eql?(groups)
      # FIXME: n^2 time. yuck.
      self.groups.each do |obj_group|
        groups.each do |comparison_group|
          if !obj_group.eql?(comparison_group)
            return false
          end
        end
      end

      return true
    end

    def ==(groups)
      self.groups == groups
    end

    def self.from_hash(hash)
      security_groups = []
      hash.each do |name, opts|
        security_group = KnifeNitrous::SecurityGroup.new(name)
        opts['rules'].each { |r| security_group.add_rule KnifeNitrous::SecurityRule.parse(r) }
        security_groups << security_group
      end
      KnifeNitrous::SecurityGroups.new(security_groups)
    end
  end
end
