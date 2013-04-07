module CloudHelpers
  def create_dns_zone(domain)
    dns.zones.create(domain: "#{domain}.")
  end

  def create_server(server)
    server_def = {
      image_id: server.ami,
      flavor_id: server.size,
      key_name: "#{server.region}-keypair",
      availability_zone: "#{server.region}a",
      groups: ["#{server.type}"],
      tags: {
        'ip'      => server.ip,
        'Name'    => server.hostname,
        'Purpose' =>  server.type
      }
    }

    if server.block_devices && !server.block_devices.to_a.empty?
      server_def[:block_device_mapping] = server.block_devices
    end

    create_keypair_for(server.region)
    cloud_server = compute(server.region).servers.create(server_def)
    cloud_server.wait_for { ready? }

    cloud_server
  end

  def create_keypair_for(region)
    keypair_name = "#{region}-keypair"
    compute(region).key_pairs.create(name: keypair_name) unless compute(region).key_pairs.get(keypair_name)
  end

  def create_security_group_for(region, type)
    compute(region).security_groups.create(name: type, description: type)
  end

  def compute(region)
    @computes ||= {}

    @computes[region] ||= Fog::Compute.new(provider: 'AWS',
                                           aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                           aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                           region: region)
    @computes[region]
  end

  def destroy_all_servers(region)
    compute(region).servers.select { |s| s.destroy }
    compute(region).servers.reload
  end

  def dns
    @dns ||= Fog::DNS.new(provider: 'AWS',
                          aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                          aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
    @dns
  end

  def setup_aws_credentials!
    FileUtils.mkdir_p(File.dirname(KnifeNitrous::AWS::CREDENTIALS_FILE))

    File.open(KnifeNitrous::AWS::CREDENTIALS_FILE, 'w') do |f|
      f.puts(YAML.dump(access_key: 'aws_access_key_id', secret_key: 'aws_secret_access_key'))
    end
  end

end

