require 'spec_helper'

require 'chef/knife/ssh'

describe KnifeNitrous::NitrousOpsworksUpdate do
  before do
    @knife_nitrous_opsworks_update = KnifeNitrous::NitrousOpsworksUpdate.new
    @knife_nitrous_opsworks_update.config[:s3_bucket] = 'example'

    FakeFS.activate!
    setup_aws_credentials!
    Fog.mock!
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe "#run" do
    context "with no items uploaded" do
      it "uploads all data bags" do
        expect { @knife_nitrous_opsworks_update.run }.to_not raise_error
      end
    end
  end
end
