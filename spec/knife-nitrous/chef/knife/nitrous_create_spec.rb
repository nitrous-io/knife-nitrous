require 'spec_helper'

require 'chef/knife/bootstrap'

describe KnifeNitrous::NitrousCreate do
  let!(:config_file)    { 'nitrous.json' }

  before do
    @knife_nitrous_create = KnifeNitrous::NitrousCreate.new
    config = File.read(File.join(Knife::Nitrous::ROOT, "spec", "fixtures", "server.json"))
    FakeFS.activate!

    FileUtils.rm_rf(config_file) if File.exists?(config_file)
    File.open(config_file, 'w') { |f| f.puts config }
    setup_aws_credentials!

    @server_collection = KnifeNitrous::ServerCollection.parse
    KnifeNitrous::ServerCollection.stub!(:parse) { @server_collection }

    @server_collection.stub!(:provision_security_group!) { true }
    @server_collection.to_a.each { |s| s.stub!(:provision) { true } }
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe "#run" do
    before do
      @knife_nitrous_create.stub!(:bootstrap_chef_for_node) { true }
    end

    it "should parse the config file" do
      KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
      @knife_nitrous_create.run
    end

    it "should provision the security group for that type" do
      @server_collection.should_receive(:provision_security_group!)
      @knife_nitrous_create.run
    end

    it "should provision servers belonging to the server collection" do
      @server_collection.to_a[0].should_receive(:provision)
      @server_collection.to_a[1].should_receive(:provision)
      @server_collection.to_a[2].should_receive(:provision)
      @knife_nitrous_create.run
    end

    it "should bootstrap chef on each of the servers in the server collection" do
      @knife_nitrous_create.should_receive(:bootstrap_chef_for_node).
                            exactly(3).times

      @knife_nitrous_create.run
    end
  end

  describe "#bootstrap_chef_for_node" do
    before do
      @server = @server_collection.to_a[0]
      @bootstrap = @knife_nitrous_create.bootstrap_chef_for_node(@server)
    end

    it "should set the ssh_user to ubuntu" do
      @bootstrap.config[:ssh_user].should == KnifeNitrous::Server::SSH_USER
      @bootstrap.config[:ssh_port].should == KnifeNitrous::Server::SSH_PORT
      @bootstrap.config[:identity_file].should == "~/.ec2/#{@server.region}-keypair.pem"
      @bootstrap.config[:run_list].should == "recipe[#{@server.type}]"

      @bootstrap.config[:chef_node_name].should == @server.hostname
      @bootstrap.config[:first_boot_attributes].should == @server.attributes

      @bootstrap.config[:distro].should == 'chef-full'
      @bootstrap.config[:use_sudo].should be_true

      Chef::Config[:knife][:hints]["ec2"].should_not be_nil
    end
  end
end
