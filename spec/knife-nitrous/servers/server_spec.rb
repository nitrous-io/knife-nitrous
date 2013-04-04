require 'spec_helper'

shared_context "mock ip" do
  before do
    @zone = create_dns_zone("actionbox.io")
    @elastic_ip = compute(server.region).addresses.create
    @main_record = @zone.records.create(value: ["ec2-#{@elastic_ip.public_ip.gsub(/\./, '-')}.ap-southeast-1.compute.amazonaws.com"],
                                        name: 'example.actionbox.io',
                                        type: 'CNAME')
    @wildcard_record = @zone.records.create(value: ["ec2-#{@elastic_ip.public_ip.gsub(/\./, '-')}.ap-southeast-1.compute.amazonaws.com"],
                                            name: '*.example.actionbox.io',
                                            type: 'CNAME')

    Fog::DNS::AWS::Records.any_instance.stub(:get).and_return(@main_record, @wildcard_record)
  end

  after do
    @elastic_ip.destroy if @elastic_ip
    @main_record.destroy if @main_record
    @wildcard_record.destroy if @wildcard_record
  end
end

describe KnifeNitrous::Server do
  let!(:server) do
    KnifeNitrous::Server.new(hostname: 'example.actionbox.io',
                       role: 'example',
                       region: 'ap-southeast-1',
                       environment: 'development',
                       size: 'm1.small',
                       ami: 'ami-deadbeef')
  end

  before :all do
    FakeFS.activate!
    setup_aws_credentials!
  end

  after :all do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  before do
    Fog::Mock.reset
  end

  describe "initialize" do
    context "env variables are not set" do
      context "credentials file exists" do
        before do
          ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil

          setup_aws_credentials!
        end

        it "should set all the instance variables correctly and also set the AWS credentials as env vars" do
          @server = KnifeNitrous::Server.new(hostname: 'example.action.io',
                                       role: 'example',
                                       region: 'ap-southeast-1',
                                       environment: 'development',
                                       size: 'm1.small',
                                       ami: 'ami-deadbeef')

          @server.hostname.should == 'example.action.io'
          @server.role.should == 'example'
          @server.region.should == 'ap-southeast-1'
          @server.environment.should == 'development'
          @server.size.should == 'm1.small'
          @server.ssh_port.should == 65100

          ENV['AWS_ACCESS_KEY_ID'].should == 'aws_access_key_id'
          ENV['AWS_SECRET_ACCESS_KEY'].should == 'aws_secret_access_key'
        end
      end

      context "credentials file does not exist" do
        before do
          ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
          KnifeNitrous::Server.any_instance.stub(:ask).and_return('aws_access_key_id', 'aws_secret_access_key')
        end

        it "should set all the instance variables correctly and also set the AWS credentials as env vars" do
          @server = KnifeNitrous::Server.new(hostname: 'example.action.io',
                                       role: 'example',
                                       region: 'ap-southeast-1',
                                       environment: 'development',
                                       size: 'm1.small',
                                       ami: 'ami-deadbeef')

          @server.hostname.should == 'example.action.io'
          @server.role.should == 'example'
          @server.region.should == 'ap-southeast-1'
          @server.environment.should == 'development'
          @server.size.should == 'm1.small'
          @server.ssh_port.should == 65100

          ENV['AWS_ACCESS_KEY_ID'].should == 'aws_access_key_id'
          ENV['AWS_SECRET_ACCESS_KEY'].should == 'aws_secret_access_key'

          File.exists?(KnifeNitrous::AWS::CREDENTIALS_FILE).should be_true
        end

      end
    end
    context "env variables are set" do
      it "should set all the instance variables correctly" do
        @server = KnifeNitrous::Server.new(hostname: 'example.action.io',
                                     role: 'example',
                                     region: 'ap-southeast-1',
                                     environment: 'development',
                                     size: 'm1.small',
                                     ami: 'ami-deadbeef')

        @server.should_not_receive(:ask)
        @server.hostname.should == 'example.action.io'
        @server.role.should == 'example'
        @server.region.should == 'ap-southeast-1'
        @server.environment.should == 'development'
        @server.size.should == 'm1.small'
        @server.ssh_port.should == 65100
      end
    end
  end

  describe "#cloud_instance" do
    context "when not provisioned" do
      it "should be nil" do
        server.cloud_instance.should be_nil
      end
    end

    context "when provisioned" do
      before do
        @existing_cloud_server = create_server(server)
      end

      it "should be a Fog::Compute::AWS::Server instance" do
        cloud_instance = server.cloud_instance

        cloud_instance.class.should == Fog::Compute::AWS::Server
        cloud_instance.image_id.should == 'ami-deadbeef'
        cloud_instance.flavor_id.should == 'm1.small'
      end
    end

    context "when provisioned (but destroyed)" do
      before do
        @existing_cloud_server = create_server(server)
        # After calling #destroy, the state will be 'shutting-down'
        @existing_cloud_server.destroy
      end

      it "should be nil" do
        server.cloud_instance.should be_nil
      end
    end
  end

  describe "#cloud_state" do
    context "when not provisioned" do
      it "should be terminated" do
        server.cloud_state.should == 'terminated'
      end
    end

    context "when terminated" do
      before do
        @existing_cloud_server = create_server(server)
        @existing_cloud_server.destroy
      end

      it "should be terminated" do
        server.cloud_state.should == 'terminated'
      end
    end

    context "when running" do
      before do
        @existing_cloud_server = create_server(server)
      end

      it "should be running" do
        server.cloud_state.should == 'running'
      end
    end

    context "when stopped" do
      before do
        @existing_cloud_server = create_server(server)
        # When mocking Fog requests, the state is 'stopping' and it
        # doesn't transition to 'stopped'
        @existing_cloud_server.stop
      end

      it "should be stopped" do
        server.cloud_state.should == 'stopping'
      end
    end
  end

  describe "#provision" do
    before do
      create_security_group_for(server.region, server.role)
      create_keypair_for(server.region)
      @zone = create_dns_zone("actionbox.io")
    end

    context "server already exists and is not terminated" do
      before do
        @existing_cloud_server = create_server(server)
      end

      context "server is stopping" do
        before do
          @existing_cloud_server.stop
        end

        it "should return nil" do
          server.provision.should be_nil
        end
      end

      context "server is running" do
        it "should return nil" do
          server.provision.should be_nil
        end

        context 'when server size is changed' do
          include_context "mock ip"
          let(:cloud_instance) { server.cloud_instance }

          before do
            cloud_instance.connection.stub(:modify_instance_attribute)
            server.stub(:tcp_test_ssh).and_return(true)
            cloud_instance.stub(:wait_for)
            server.size = "m1.medium"
          end

          it 'changes size of the instance' do
            cloud_instance.should_receive(:stop)
            cloud_instance.connection.should_receive(:modify_instance_attribute).
              with(cloud_instance.id, hash_including({ 'InstanceType.Value' => 'm1.medium' }))
            cloud_instance.should_receive(:start)
            server.provision
          end

          it 'does not modify the instance when the new size is invalid' do
            server.size = 'm1.invalid-size'
            cloud_instance.connection.should_not_receive(:modify_instance_attribute)
            server.provision
          end

          it "re-assigns the ip associate with the server" do
            server.provision
            server.ip.should eq(@elastic_ip.public_ip)
          end
        end
      end
    end

    context "server doesn't exist" do
      before do
        server.stub(:tcp_test_ssh).and_return(true)
      end

      context "DNS entry for the server does not exist" do
        before do
          Fog::DNS::AWS::Records.any_instance.stub(:get).and_return nil
        end

        it "should create a new DNS record, elastic IP, and provision a server" do
          cloud_instance = server.provision
          new_ip = compute(server.region).addresses.first

          new_ip.should_not be_nil

          cloud_instance.tags[:Name].should == server.hostname
          cloud_instance.tags[:ip].should == new_ip.public_ip
          cloud_instance.tags[:Purpose].should == server.role
          cloud_instance.public_ip_address.should == new_ip.public_ip
          cloud_instance.image_id.should == server.ami
          cloud_instance.flavor_id.should == server.size
          cloud_instance.availability_zone.should == "ap-southeast-1a"
          cloud_instance.key_name.should == "ap-southeast-1-keypair"
          cloud_instance.groups.should == ["example"]
        end
      end

      context "DNS entry for the server exists" do
        include_context "mock ip"

        context "Elastic IP associated with the DNS entry does not exist" do
          before do
            @elastic_ip.destroy
            @elastic_ip = nil
          end

          it "should create an instance with the public_ip which is different from the one which exists in the DNS records" do
            cloud_instance = server.provision
            new_ip = compute(server.region).addresses.first
            @main_record.reload.value.should == cloud_instance.dns_name
            @wildcard_record.reload.value.should == cloud_instance.dns_name

            cloud_instance.tags[:Name].should == server.hostname
            cloud_instance.tags[:ip].should == new_ip.public_ip
            cloud_instance.tags[:Purpose].should == server.role
            cloud_instance.public_ip_address.should == new_ip.public_ip
            cloud_instance.image_id.should == server.ami
            cloud_instance.flavor_id.should == server.size
            cloud_instance.availability_zone.should == "ap-southeast-1a"
            cloud_instance.key_name.should == "ap-southeast-1-keypair"
            cloud_instance.groups.should == ["example"]
          end
        end

        context "Elastic IP associated with the DNS entry does exist" do
          it "should create an instance with the public_ip which is the same as the associated with the existing elastic IP" do
            cloud_instance = server.provision

            cloud_instance.tags[:Name].should == server.hostname
            cloud_instance.tags[:ip].should == @elastic_ip.public_ip
            cloud_instance.tags[:Purpose].should == server.role
            cloud_instance.public_ip_address.should == @elastic_ip.public_ip
            cloud_instance.image_id.should == server.ami
            cloud_instance.flavor_id.should == server.size
            cloud_instance.availability_zone.should == "ap-southeast-1a"
            cloud_instance.key_name.should == "ap-southeast-1-keypair"
            cloud_instance.groups.should == ["example"]
          end
        end
      end
    end
  end

  describe "#restart" do
    include_context "mock ip"

    let(:cloud_instance) { server.cloud_instance }

    before do
      create_security_group_for(server.region, server.role)
      create_keypair_for(server.region)
      create_dns_zone("actionbox.io")
      create_server(server)
      cloud_instance.stub(:wait_for)
      server.stub(:tcp_test_ssh).and_return(true)
    end

    it 'restarts the server' do
      cloud_instance.should_receive(:stop)
      cloud_instance.should_receive(:start)
      server.restart
    end

    context 'when flavor_id is specified' do
      it 'changes size of the instance' do
        cloud_instance.connection.should_receive(:modify_instance_attribute).
          with(cloud_instance.id, hash_including({ 'InstanceType.Value' => 'm1.medium' }))
        server.restart 'm1.medium'
      end

      context 'when the flavor_id is invalid' do
        it 'does not modify the instance' do
          cloud_instance.connection.should_not_receive(:modify_instance_attribute)
          server.restart 'invalid.flavor'
        end
      end
    end

    it "re-assigns the ip associate with the server" do
      server.restart
      server.ip.should eq(@elastic_ip.public_ip)
    end
  end
end
