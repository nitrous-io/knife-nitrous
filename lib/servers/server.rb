module KnifeNitrous
  class Server
    include KnifeNitrous::AWS

    attr_accessor :hostname, :type, :region, :environment,
                  :size, :ami, :block_devices, :attributes,
                  :run_list, :availability_zone, :security_groups,
                  :iam_role, :user_data

    attr_reader   :ssh_port, :ip

    SSH_PORT = 65100
    SSH_USER = 'ubuntu'.freeze

    def initialize(opts = {})
      load_credentials!

      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }

      @run_list = [] if @run_list.nil?
      @ssh_port = SSH_PORT
      @cloud_instance = nil
    end

    def attributes
      @attributes.merge!('region' => self.region)
    end

    def aws_dns_name
      self.cloud_instance(include_all: true).dns_name
    end

    def cloud_instance(opts = {})
      unless @cloud_instance
        @cloud_instance = compute.servers.all.select do |s|
          true_condition = if opts[:include_all]
            true
          else
            s.state != 'terminated' && s.state != 'shutting-down'
          end

          true_condition && s.tags['Name'] == self.hostname
        end.first
      end

      @cloud_instance
    end

    def cloud_state
      cloud_instance.try(:state) || 'terminated'
    end

    def inspect
      "#KnifeNitrous::Server #{self.hostname}: #{self.region}: #{self.size} | attrs=> #{self.attributes.inspect}"
    end

    def provision
      if cloud_state == 'terminated'
        # Check if name exists in Route53
        assign_ip_from_dns!

        if @ip.nil?
          create_elastic_ip!
        end

        create_instance
      elsif cloud_state == 'running'
        if self.size != cloud_instance.flavor_id
          restart self.size
        end
      end
    end

    def restart(flavor_id=nil)
      cloud_instance.stop
      cloud_instance.wait_for { print "."; state == 'stopped' }
      if flavor_id && valid_flavor?(flavor_id)
        cloud_instance.flavor_id = flavor_id
        cloud_instance.service.modify_instance_attribute cloud_instance.id, {
          'InstanceType.Value' => flavor_id
        }
      end
      cloud_instance.start
      cloud_instance.wait_for { print "."; ready? }
      reassign_ip!
    end

    # Setup EBS volumes for the current server. This doesnt resize existing
    # volumes, only tried to setup new volumes with correct size by comparing
    # the attached volumes with block_devices specified in config
    def setup_volumes
      current_devices = cloud_instance.volumes.all.map(&:device)

      new_volumes = block_devices.to_a.select do |block|
        !current_devices.include? block.name
      end

      puts "Provisioning New Volumes" unless new_volumes.empty?

      new_volumes.each do |block|
        volume = cloud_instance.volumes.new(
                                             device: block.name,
                                             size: block.size,
                                             snapshot_id: block.snapshot_id,
                                             delete_on_termination: block.delete_on_termination,
                                             availability_zone: cloud_instance.availability_zone
                                           )
        volume.server = cloud_instance
        volume.save

        # Wait for the volume to be attached
        while volume.state != 'in-use' do
          print "."; sleep 1
        end

        puts "\nProvisioned: #{volume.device}: #{volume.size} #{volume.snapshot_id}"
      end
    end

    protected
    def valid_flavor?(flavor_id)
      cloud_instance.service.flavors.all.any? { |flavor| flavor.id == flavor_id }
    end

    def reassign_ip!
      assign_ip_from_dns!
      if @ip.nil?
        create_elastic_ip!
      end
      compute.associate_address(cloud_instance.id, @ip)
      print(".") until tcp_test_ssh { puts("\nDone") }
    end

    def assign_ip_from_dns!
      if (zone = zone_from(self.hostname)).present?
        record = zone.records.get(self.hostname)

        if record
          cname = record.value.first
          return unless cname

          cname_matcher = cname.match(/ec2-(\d+)-(\d+)-(\d+)-(\d+)\./)

          if cname_matcher && cname_matcher.size == 5
            matched_ip = "#{cname_matcher[1]}.#{cname_matcher[2]}.#{cname_matcher[3]}.#{cname_matcher[4]}"
            # If the elastic IP does not exist, then @ip will be set to nil
            # and bombay will create a new elastic IP address
            @ip = compute.addresses.get(matched_ip).try(:public_ip)
          end
        end
      end
    end

    def create_dns_record(domain_name)
      if (zone = zone_from(self.hostname)).present?
        # If the DNS record exists, that means that DNS entry exists
        # for an elastic IP which has been released
        if (record = zone.records.get(self.hostname))
          change_dns_value(record, domain_name)

          # If this is an n2oapp.com URL, then update the DNS value there
          # as well
          if self.hostname =~ /n2oapp\.com/
            if (record = zone.records.get("*.#{self.hostname}"))
              change_dns_value(record, domain_name)
            end
          end
        else
          record = zone.records.create(value: domain_name,
                                       name: self.hostname,
                                       type: 'CNAME',
                                       ttl: 60)

          # Box Hosts need wildcard domain too because we allow
          # users to access individual boxes
          if self.hostname =~ /n2oapp\.com$/
            zone.records.create(value: domain_name,
                                name: "*.#{self.hostname}",
                                type: 'CNAME',
                                ttl: 60)
          end
        end
      end
    end

    def create_elastic_ip!
      result = compute.allocate_address
      @ip = result.body['publicIp']
    end

    def create_instance
      server_def = {
        image_id: self.ami,
        flavor_id: self.size,
        key_name: "#{self.region}-keypair",
        user_data: user_data,
        availability_zone: self.availability_zone || "#{self.region}a",
        groups: self.security_groups,
        iam_instance_profile_name: self.iam_role,
        tags: {
          ip: self.ip,
          Name: self.hostname,
          Purpose: self.type
        }
      }

      if self.block_devices && !self.block_devices.to_a.empty?
        server_def[:block_device_mapping] = self.block_devices.to_hash
      end

      server = compute.servers.create(server_def)

      if server
        server.wait_for { print "."; ready? }
        compute.associate_address(server.id, self.ip)
        server.reload
        create_dns_record(server.dns_name)

        print(".") until tcp_test_ssh {
          puts("\nDone")
        }
      end

      server.reload
    end

    def change_dns_value(record, value)
      record.destroy
      record.value = value
      record.save
    end
  end
end
