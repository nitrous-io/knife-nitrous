require 'spec_helper'

describe KnifeNitrous::BlockDevice do
  describe 'initialize' do
    it 'should initialize instance variables' do
      block_device = KnifeNitrous::BlockDevice.new(name: '/dev/sdf', snapshot_id: 'snap-deadbeef', size: 20, delete_on_termination: true)
      block_device.name.should == '/dev/sdf'
      block_device.snapshot_id.should == 'snap-deadbeef'
      block_device.size.should == 20
      block_device.delete_on_termination.should be_true
    end
  end

  describe "#to_hash" do
    it 'should return a hash which has attributes mapped to AWS-friendly attribute names' do
      block_device = KnifeNitrous::BlockDevice.new(name: '/dev/sdf', snapshot_id: 'snap-deadbeef', size: 20, delete_on_termination: true)
      block_device.to_hash.should == { 'DeviceName' => '/dev/sdf', 'Ebs.SnapshotId' => 'snap-deadbeef', 'Ebs.VolumeSize' => 20, 'Ebs.DeleteOnTermination' => 'true' }
    end
  end
end
