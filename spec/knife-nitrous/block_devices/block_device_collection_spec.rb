require 'spec_helper'

describe KnifeNitrous::BlockDeviceCollection do
  describe "initialize" do
    it "should initialize an array of block devices" do
      collection = KnifeNitrous::BlockDeviceCollection.new([{name: '/dev/sdf', snapshot_id: 'snap-deadbeef', size: 20, delete_on_termination: true},
                                                      KnifeNitrous::BlockDevice.new(name: '/dev/sdg', snapshot_id: 'snap-deadbeef', size: 120, delete_on_termination: false)])

      collection.size.should == 2
      block_device_1, block_device_2 = collection.to_a

      block_device_1.class.should == KnifeNitrous::BlockDevice
      block_device_2.class.should == KnifeNitrous::BlockDevice

      block_device_1.name.should == '/dev/sdf'
      block_device_1.snapshot_id.should == 'snap-deadbeef'
      block_device_1.size.should == 20
      block_device_1.delete_on_termination.should be_true

      block_device_2.name.should == '/dev/sdg'
      block_device_2.snapshot_id.should == 'snap-deadbeef'
      block_device_2.size.should == 120
      block_device_2.delete_on_termination.should be_false
    end
  end

  describe "#add" do
    it "should add either a KnifeNitrous::Device object or a hash to the collection" do
      collection = KnifeNitrous::BlockDeviceCollection.new

      collection.add({name: '/dev/sdf', snapshot_id: 'snap-deadbeef', size: 20, delete_on_termination: true})
      collection.add(KnifeNitrous::BlockDevice.new(name: '/dev/sdg', snapshot_id: 'snap-deadbeef', size: 120, delete_on_termination: false))

      collection.size.should == 2
      block_device_1, block_device_2 = collection.to_a

      block_device_1.class.should == KnifeNitrous::BlockDevice
      block_device_2.class.should == KnifeNitrous::BlockDevice

      block_device_1.name.should == '/dev/sdf'
      block_device_1.snapshot_id.should == 'snap-deadbeef'
      block_device_1.size.should == 20
      block_device_1.delete_on_termination.should be_true

      block_device_2.name.should == '/dev/sdg'
      block_device_2.snapshot_id.should == 'snap-deadbeef'
      block_device_2.size.should == 120
      block_device_2.delete_on_termination.should be_false
    end
  end

  describe "#to_hash" do
    it "should return an array of BlockDevice hash's" do
      collection = KnifeNitrous::BlockDeviceCollection.new([{name: '/dev/sdf', snapshot_id: 'snap-deadbeef', size: 20, delete_on_termination: true},
                                                     KnifeNitrous::BlockDevice.new(name: '/dev/sdg', snapshot_id: 'snap-deadbeef', size: 120, delete_on_termination: false)])
      collection.to_hash.should == [
        { 'DeviceName' => '/dev/sdf', 'Ebs.SnapshotId' => 'snap-deadbeef', 'Ebs.VolumeSize' => 20, 'Ebs.DeleteOnTermination' => 'true' },
        { 'DeviceName' => '/dev/sdg', 'Ebs.SnapshotId' => 'snap-deadbeef', 'Ebs.VolumeSize' => 120, 'Ebs.DeleteOnTermination' => 'false' }
      ]
    end
  end

end
