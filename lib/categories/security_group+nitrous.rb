class Fog::Compute::AWS::SecurityGroup < Fog::Model
  def sync(rules)
    existing_rules = nitrous_rules

    to_authorize   = rules - existing_rules
    to_deauthorize = existing_rules - rules

    to_authorize.each    { |r| authorize(r)   }
    to_deauthorize.each  { |r| deauthorize(r) }

    self.reload
  end

  protected
  def authorize(rule)
    if rule.is_source_ip?
      authorize_port_range(rule.port_range,
                           cidr_ip: rule.source,
                           ip_protocol: rule.protocol)
    else
      authorize_port_range(rule.port_range,
                           group: rule.source,
                           owner_id: self.owner_id,
                           ip_protocol: rule.protocol)
    end
  # somehow running authorize_port_range for a security group that has format
  # user:group multiple times will fail. This catches that and just print out
  # the exception but will continue
  rescue Fog::Compute::AWS::Error => e
    unless e.to_s.match /InvalidPermission\.Duplicate/
      raise e
    end
  end

  def nitrous_rules
    set = Set.new

    self.ip_permissions.each do |permission|
      start_port, end_port = permission['fromPort'], permission['toPort']
      protocol = permission['ipProtocol']

      (permission['ipRanges'] + permission['groups']).each do |p|
        source = p['cidrIp'] || p['groupName']
        set.add KnifeNitrous::SecurityRule.new(ports: "#{start_port}-#{end_port}",
                                         source: source,
                                         protocol: protocol)
      end
    end

    set
  end

  def deauthorize(rule)
    if rule.is_source_ip?
      revoke_port_range(rule.port_range,
                        cidr_ip: rule.source,
                        ip_protocol: rule.protocol)
    else
      revoke_port_range(rule.port_range,
                        group: rule.source,
                        owner_id: self.owner_id,
                        ip_protocol: rule.protocol)
    end
  end
end
