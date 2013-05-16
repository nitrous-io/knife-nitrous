require 'spec_helper'

describe KnifeNitrous::NitrousSetupVolumes do
  let!(:config_file) { 'nitrous.json' }

  before do
    @knife_nitrous_setup_volumes = described_class.new

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

  describe '#run' do
    let!(:chef_runner) { double :chef_runner }

    before do
      @collection = @server_collection.to_a
      @collection[0].stub!(:cloud_state) { 'running' }
      @collection[1].stub!(:cloud_state) { 'running' }
      @collection[2].stub!(:cloud_state) { 'running' }

      @knife_nitrous_setup_volumes.config[:hostname] = @collection[1].hostname
      @knife_nitrous_setup_volumes.stub!(:chef_runner_for_node) { chef_runner }
      chef_runner.stub!(:run)
    end

    it 'requires hostname to be specified' do
      @knife_nitrous_setup_volumes.config[:hostname] = nil
      expect {
        @knife_nitrous_setup_volumes.run
      }.to raise_error
    end

    it "resizes the specified server volumes" do
      @collection[0].should_not_receive(:setup_volumes)
      @collection[1].should_receive(:setup_volumes)
      @collection[2].should_not_receive(:setup_volumes)
      @knife_nitrous_setup_volumes.run
    end
  end
end
