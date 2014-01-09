require 'spec_helper'

describe KnifeNitrous::ServerCollection do
  let!(:config_file)    { 'test.yml' }
  let!(:sg_directory)   { 'security_groups' }
  let!(:config) { File.read(File.join(Knife::Nitrous::ROOT, "spec", "fixtures", "server_defs", "server.yml")) }

  before do
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

    setup_aws_credentials!
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe ".parse" do
    context "server config file doesn't exist in cwd" do
      before do
        FileUtils.rm_rf('test.yml')
      end

      it "should return nil" do
        KnifeNitrous::ServerCollection.parse(config_file, sg_directory).should be_nil
      end
    end

    context "config file does exist in cwd" do
      context "config file has invalid YAML" do
        before do
          File.open(config_file, 'w') { |f| f.puts ">abc;" }
        end

        it "should return nil" do
          KnifeNitrous::ServerCollection.parse(config_file, sg_directory).should be_nil
        end
      end

      context "config file has valid YAML" do
        context "with servers_common defined" do
          let!(:config) { File.read(File.join(Knife::Nitrous::ROOT, "spec", "fixtures", "server_defs", "server-common.yml")) }

          it "merges from servers_common into an individual server's config" do
            server_collection = KnifeNitrous::ServerCollection.parse(config_file, sg_directory)
            server_collection.to_a.should_not be_empty
            server_collection.to_a.each do |server|
              server.hostname.should_not eq("will-be-overridden")
              server.attributes["base_template"].should eq("common_base_template")
            end
          end

          it "uses attributes from servers_common if not overridden in an individual server's attributes" do
            server_collection = KnifeNitrous::ServerCollection.parse(config_file, sg_directory)
            server_collection.to_a.each do |server|
              server.attributes['nitrous']['shared_attr'].should eq('sharing-is-caring')
            end
          end
        end

        it "should return a server collection" do
          server_collection = KnifeNitrous::ServerCollection.parse(config_file, sg_directory)
          server_collection.class.should == KnifeNitrous::ServerCollection
          server_collection.size.should == 3
        end

        it "should contain an array of KnifeNitrous::Server objects" do
          server_collection = KnifeNitrous::ServerCollection.parse(config_file, sg_directory)
          servers = server_collection.to_a

          server_collection.type.should == 'root-www'
          server_collection.security_group_hash.should be_present

          servers[0].hostname.should == 'nitrous.io'
          servers[0].size.should == 'm1.small'
          servers[0].region.should == 'us-east-1'
          servers[0].availability_zone.should == 'us-east-1c'
          servers[0].type.should == 'root-www'
          servers[0].iam_role.should == 'foobar_role'
          servers[0].run_list.should == ['recipe[root-www_cookbook]']
          servers[0].ami.should == 'ami-deadbeef'
          servers[0].attributes.should == { 'environment' => 'production', 'region' => 'us-east-1' }

          servers[0].block_devices.to_a.should be_empty

          servers[1].hostname.should == 'sensu-usw1.nitrous.io'
          servers[1].size.should == 'm1.small'
          servers[1].region.should == 'us-west-1'
          servers[1].type.should == 'root-www'
          servers[1].iam_role.should == 'foobar_role'
          servers[1].run_list.should == ['recipe[root-www_cookbook]']
          servers[1].ami.should == 'ami-deadbeef'
          servers[1].attributes.should == { 'environment' => 'production', 'region' => 'us-west-1' }

          block_devices = servers[1].block_devices.to_a
          block_devices.size.should == 2

          block_devices[0].name.should == '/dev/sdf'
          block_devices[0].snapshot_id.should == 'snap-deadbeef'
          block_devices[0].size.should == 20
          block_devices[0].delete_on_termination.should == 'false'

          block_devices[1].name.should == '/dev/sdg'
          block_devices[1].snapshot_id.should == 'snap-deadbeef'
          block_devices[1].size.should == 40
          block_devices[1].delete_on_termination.should == 'false'

          servers[2].hostname.should == 'sensu-staging.nitrous.io'
          servers[2].size.should == 'm1.large'
          servers[2].type.should == 'root-www'
          servers[2].run_list.should == ['recipe[root-www_cookbook]']
          servers[2].iam_role.should == 'foobar_role'
          servers[2].region.should == 'us-west-1'
          servers[2].ami.should == 'ami-deadbeef'
          servers[2].attributes.should == { 'environment' => 'staging', 'region' => 'us-west-1' }

          block_devices = servers[2].block_devices.to_a
          block_devices.size.should == 1

          block_devices[0].name.should == '/dev/sdf'
          block_devices[0].snapshot_id.should == 'snap-cafedead'
          block_devices[0].size.should == 20
          block_devices[0].delete_on_termination.should == 'false'
        end
      end
    end
  end

end
