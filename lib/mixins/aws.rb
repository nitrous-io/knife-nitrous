module KnifeNitrous
  module AWS
    CREDENTIALS_FILE = File.join(Dir.home, '.chef', 'aws.json')

    def compute
      @compute ||= Fog::Compute.new(provider: 'AWS',
                                    aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                    aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                    region: self.region)
    end

    def dns
      @dns ||= Fog::DNS.new(provider: 'AWS',
                            aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                            aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
    end

    def load_credentials!
      if File.exists?(CREDENTIALS_FILE)
        credentials = YAML.load(File.read(CREDENTIALS_FILE))
        ENV['AWS_ACCESS_KEY_ID'] = credentials['access_key']
        ENV['AWS_SECRET_ACCESS_KEY'] = credentials['secret_key']
      else
        raise "Make sure you have ~/.chef/aws.json with two keys: " +
              "access_key with the value AWS Access Key ID, " +
              "secret_key with the value AWS Secret Access Key"
      end
    end

    def set_credentials!(access_key, secret_key)
      FileUtils.mkdir_p(File.dirname(CREDENTIALS_FILE))

      File.open(CREDENTIALS_FILE, 'w') do |f|
        f.puts(YAML.dump(access_key: access_key, secret_key: secret_key))
      end

      FileUtils.chmod 0700, File.dirname(CREDENTIALS_FILE)
      FileUtils.chmod 0600, CREDENTIALS_FILE

      load_credentials!
    end

    def tcp_test_ssh
      tcp_socket = TCPSocket.new(self.aws_dns_name, self.ssh_port)
      readable = IO.select([tcp_socket], nil, nil, 5)
      if readable
        yield
        true
      else
        false
      end

    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, IOError
      sleep 2
      false
    rescue Errno::EPERM, Errno::ETIMEDOUT
      false
    ensure
      tcp_socket && tcp_socket.close
    end

    def zone_from(hostname)
      parsed_domain = Domainatrix.parse(hostname)
      root_domain = "#{parsed_domain.domain}.#{parsed_domain.public_suffix}"
      dns.zones.select { |z| z.domain == "#{root_domain}." }.first
    end
  end
end
