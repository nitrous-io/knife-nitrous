require 'spec_helper'

require 'chef/knife/ssh'

describe KnifeNitrous::NitrousProvision do
  let!(:config_file)    { 'nitrous.json' }

  before do
    @knife_nitrous_provision = KnifeNitrous::NitrousProvision.new

    config = File.read(File.join(Knife::Nitrous::ROOT, "spec", "fixtures", "server.json"))
    FakeFS.activate!

    FileUtils.rm_rf(config_file) if File.exists?(config_file)
    File.open(config_file, 'w') { |f| f.puts config }
    setup_aws_credentials!

    @server_collection = KnifeNitrous::ServerCollection.parse
    KnifeNitrous::ServerCollection.stub!(:parse) { @server_collection }
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe "#run" do
    context "with no params set and all servers are running" do
      let!(:chef_runner)            { double :chef_runner }
      let!(:chef_attributes_loader) { double :chef_attributes_loader }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_provision.stub!(:chef_runner_for_node) { chef_runner }
        @knife_nitrous_provision.stub!(:chef_attributes_loader_for_node) { chef_attributes_loader }

        chef_runner.stub!(:run)
        chef_attributes_loader.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_provision.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_runner_for_node).
                                 exactly(3).times.
                                 and_return(chef_runner)
        chef_runner.should_receive(:run).exactly(3).times

        @knife_nitrous_provision.run
      end

      it "should load run-time attributes on the server each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_attributes_loader_for_node).
                                 exactly(3).times.
                                 and_return(chef_attributes_loader)

        chef_attributes_loader.should_receive(:run).exactly(3).times

        @knife_nitrous_provision.run
      end
    end

    context "with no params set and only two servers are running" do
      let!(:chef_runner)            { double :chef_runner }
      let!(:chef_attributes_loader) { double :chef_attributes_loader }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'stopped' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_provision.stub!(:chef_runner_for_node) { chef_runner }
        @knife_nitrous_provision.stub!(:chef_attributes_loader_for_node) { chef_attributes_loader }

        chef_runner.stub!(:run)
        chef_attributes_loader.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_provision.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_runner_for_node).
                                 exactly(2).times.
                                 and_return(chef_runner)
        chef_runner.should_receive(:run).exactly(2).times

        @knife_nitrous_provision.run
      end

      it "should load run-time attributes on the server each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_attributes_loader_for_node).
                                 exactly(2).times.
                                 and_return(chef_attributes_loader)

        chef_attributes_loader.should_receive(:run).exactly(2).times

        @knife_nitrous_provision.run
      end
    end

    context "with the region set" do
      let!(:chef_runner)            { double :chef_runner }
      let!(:chef_attributes_loader) { double :chef_runner }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_provision.config[:region] = ['us-east-1']
        @knife_nitrous_provision.stub!(:chef_runner_for_node)             { chef_runner }
        @knife_nitrous_provision.stub!(:chef_attributes_loader_for_node)  { chef_attributes_loader }

        chef_runner.stub!(:run)
        chef_attributes_loader.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_provision.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_runner_for_node).
                                 once.
                                 and_return(chef_runner)
        chef_runner.should_receive(:run).once

        @knife_nitrous_provision.run
      end

      it "should load run-time attributes on the server each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_attributes_loader_for_node).
                                 once.
                                 and_return(chef_attributes_loader)

        chef_attributes_loader.should_receive(:run).once

        @knife_nitrous_provision.run
      end
    end

    context "with the hostname set" do
      let!(:chef_runner)            { double :chef_runner }
      let!(:chef_attributes_loader) { double :chef_attributes_loader }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_provision.config[:hostname] = 'sensu-staging.nitrous.io'
        @knife_nitrous_provision.stub!(:chef_runner_for_node)             { chef_runner }
        @knife_nitrous_provision.stub!(:chef_attributes_loader_for_node)  { chef_attributes_loader }

        chef_runner.stub!(:run)
        chef_attributes_loader.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_provision.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_provision.should_receive(:chef_runner_for_node).
                                 once.
                                 and_return(chef_runner)
        chef_runner.should_receive(:run).once

        @knife_nitrous_provision.run
      end
    end
  end

  describe "#chef_runner_for_node" do
    before do
      @server = @server_collection.to_a[0]
      @timestamp = Time.now.to_i

      @ssh = @knife_nitrous_provision.chef_runner_for_node(@server, @timestamp)
    end

    it "should set the name_args to include the server name and the chef-client command" do
      @ssh.name_args.should == [@server.hostname, "sudo chef-client -c /etc/chef/client.rb -j /tmp/#{@server.type}-#{@timestamp}.json"]
    end

    it "should set the ssh_user to the default nitrous sudo user" do
      @ssh.config[:ssh_user].should == KnifeNitrous::Server::SSH_USER
    end

    it "should set the ssh_port to the default nitrous ssh port" do
      @ssh.config[:ssh_port].should == KnifeNitrous::Server::SSH_PORT
    end

    it "should set the identify_file to be the default key which includes the region" do
      @ssh.config[:identity_file].should == "~/.ec2/#{@server.region}-keypair.pem"
    end

    it "should set the manual flag to be true" do
      @ssh.config[:manual].should be_true
    end

    it "should set the on_error flag to be :raise" do
      @ssh.config[:on_error].should == :raise
    end
  end

  describe "#chef_attributes_loader_for_node" do
    before do
      @server = @server_collection.to_a[0]
      @timestamp = Time.now.to_i

      @ssh = @knife_nitrous_provision.chef_attributes_loader_for_node(@server, @timestamp)
    end

    it "should set the name_args to include the server name and the chef-client command" do
      @ssh.name_args.should == [
                                  @server.hostname,
                                  "sudo /opt/chef/embedded/bin/ruby -e \"require 'json'; File.open('/tmp/root-www-#{@timestamp}.json', 'w') { |f| f.puts('{\\\"environment\\\":\\\"production\\\"}') }\""
                               ]
    end

    it "should set the ssh_user to the default nitrous sudo user" do
      @ssh.config[:ssh_user].should == KnifeNitrous::Server::SSH_USER
    end

    it "should set the ssh_port to the default nitrous ssh port" do
      @ssh.config[:ssh_port].should == KnifeNitrous::Server::SSH_PORT
    end

    it "should set the identify_file to be the default key which includes the region" do
      @ssh.config[:identity_file].should == "~/.ec2/#{@server.region}-keypair.pem"
    end

    it "should set the manual flag to be true" do
      @ssh.config[:manual].should be_true
    end

    it "should set the on_error flag to be :raise" do
      @ssh.config[:on_error].should == :raise
    end
  end

end
