require 'spec_helper'

require 'chef/knife/bootstrap'

describe KnifeNitrous::NitrousBootstrap do
  let!(:config_file)    { 'nitrous.json' }

  before do
    @knife_nitrous_bootstrap = KnifeNitrous::NitrousBootstrap.new

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
      let!(:bootstrap) { double :bootstrap }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_bootstrap.stub!(:bootstrap_chef_for_node) { bootstrap }
        bootstrap.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_bootstrap.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_bootstrap.should_receive(:bootstrap_chef_for_node).
                                 exactly(3).times.
                                 and_return(bootstrap)
        bootstrap.should_receive(:run).exactly(3).times

        @knife_nitrous_bootstrap.run
      end
    end

    context "with no params set and only two servers are running" do
      let!(:bootstrap) { double :bootstrap }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'stopped' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_bootstrap.stub!(:bootstrap_chef_for_node) { bootstrap }
        bootstrap.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_bootstrap.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_bootstrap.should_receive(:bootstrap_chef_for_node).
                                 exactly(2).times.
                                 and_return(bootstrap)
        bootstrap.should_receive(:run).exactly(2).times

        @knife_nitrous_bootstrap.run
      end
    end

    context "with the region set" do
      let!(:bootstrap) { double :bootstrap }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_bootstrap.config[:region] = ['us-east-1']
        @knife_nitrous_bootstrap.stub!(:bootstrap_chef_for_node) { bootstrap }
        bootstrap.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_bootstrap.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_bootstrap.should_receive(:bootstrap_chef_for_node).
                                 once.
                                 and_return(bootstrap)
        bootstrap.should_receive(:run).once

        @knife_nitrous_bootstrap.run
      end
    end

    context "with the hostname set" do
      let!(:bootstrap) { double :bootstrap }

      before do
        @server_collection.to_a[0].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[1].stub!(:cloud_state) { 'running' }
        @server_collection.to_a[2].stub!(:cloud_state) { 'running' }

        @knife_nitrous_bootstrap.config[:hostname] = 'sensu-staging.nitrous.io'
        @knife_nitrous_bootstrap.stub!(:bootstrap_chef_for_node) { bootstrap }
        bootstrap.stub!(:run)
      end

      it "should parse the config file" do
        KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
        @knife_nitrous_bootstrap.run
      end

      it "should run chef-client on each of the servers in the server collection" do
        @knife_nitrous_bootstrap.should_receive(:bootstrap_chef_for_node).
                                 once.
                                 and_return(bootstrap)
        bootstrap.should_receive(:run).once

        @knife_nitrous_bootstrap.run
      end
    end
  end

  describe "#bootstrap_chef_for_node" do
    before do
      @server = @server_collection.to_a[0]
      @bootstrap = @knife_nitrous_bootstrap.bootstrap_chef_for_node(@server)
    end

    it "should set the ssh_user to the default nitrous user" do
      @bootstrap.config[:ssh_user].should == KnifeNitrous::Server::SSH_USER
    end

    it "should set the ssh_port to the default nitrous ssh port" do
      @bootstrap.config[:ssh_port].should == KnifeNitrous::Server::SSH_PORT
    end

    it "should set the identify_file to be the default key which includes the region" do
      @bootstrap.config[:identity_file].should == "~/.ec2/#{@server.region}-keypair.pem"
    end

    it "should set the run list to be the server's type" do
      @bootstrap.config[:run_list].should == "recipe[#{@server.type}-cookbook]"
    end

    it "should set the chef node name to be the server's hostname" do
      @bootstrap.config[:chef_node_name].should == @server.hostname
    end

    it "should set first_boot_attributes to be the server's attributes" do
      @bootstrap.config[:first_boot_attributes].should == @server.attributes
    end

    it "should set the distro to be chef-full" do
      @bootstrap.config[:distro].should == 'chef-full'
    end

    it "should use sudo by default" do
      @bootstrap.config[:use_sudo].should be_true
    end

    it "should set ec2 to be true" do
      Chef::Config[:knife][:hints]["ec2"].should_not be_nil
    end
  end
end

