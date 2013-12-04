require 'spec_helper'

require 'chef/knife/bootstrap'

describe KnifeNitrous::NitrousCreate do
  let!(:config_file)    { 'test.yml' }
  let!(:sg_directory)   { 'security_groups' }

  before do
    @knife_nitrous_create = KnifeNitrous::NitrousCreate.new
    config = File.read(File.join(Knife::Nitrous::ROOT, "spec", "fixtures", "server_defs", "server.yml"))

    sg_directives = {}

    Dir.glob("#{File.join(Knife::Nitrous::ROOT, 'spec', 'fixtures', 'security_groups')}/**/*").each do |file|
      sg_directives.merge!({ File.basename(file) => File.read(file) })
    end

    FakeFS.activate!

    FileUtils.rm_rf(config_file) if File.exists?(config_file)
    File.open(config_file, 'w') { |f| f.puts config }
    FileUtils.rm_rf(sg_directory) if File.exists?(sg_directory)
    FileUtils.mkdir(sg_directory)
    sg_directives.each do |sg_file, opts|
      File.open("#{sg_directory}/#{sg_file}", 'w') { |f| f.puts opts }
    end

    @knife_nitrous_create.config[:yaml_file] = config_file
    @knife_nitrous_create.config[:sg_directory] = sg_directory

    setup_aws_credentials!

    @server_collection = KnifeNitrous::ServerCollection.parse(config_file, sg_directory)
    KnifeNitrous::ServerCollection.stub!(:parse) { @server_collection }

    @server_collection.stub!(:provision_security_group!) { true }
    @server_collection.to_a.each { |s| s.stub!(:provision) { true } }
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe "#run" do
    let!(:bootstrap) { double :bootstrap }

    before do
      bootstrap.stub!(:run)
      @knife_nitrous_create.stub!(:bootstrap_chef_for_node) { bootstrap }
    end

    it "should parse the config file" do
      KnifeNitrous::ServerCollection.should_receive(:parse).and_return(@server_collection)
      @knife_nitrous_create.run
    end

    it "should provision the security group for that type" do
      @knife_nitrous_create.should_receive(:provision_security_group!).with(@server_collection, @server_collection.security_group_hash)
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
                            exactly(3).times.
                            and_return(bootstrap)

      @knife_nitrous_create.run
    end

    it "should run bootstrap on each of the servers in the server collection" do
      bootstrap.should_receive(:run).exactly(3).times
      @knife_nitrous_create.run
    end
  end

  describe "#bootstrap_chef_for_node" do
    before do
      @server = @server_collection.to_a[0]
      @server.stub!(:aws_dns_name) { 'fake.local' }

      @bootstrap = @knife_nitrous_create.bootstrap_chef_for_node(@server)
    end

    it "should set the server to connect to to it's AWS DNS name" do
      @bootstrap.name_args.should == ['fake.local']
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

    it "should set the run list to be the server's run_list" do
      @bootstrap.config[:run_list].should == @server.run_list
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
