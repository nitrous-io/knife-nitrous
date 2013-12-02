require 'spec_helper'

describe KnifeNitrous::SecurityGroups do
  describe 'initialize' do
    it 'should initialize all the instance variables' do
      sec_groups = KnifeNitrous::SecurityGroups.new([KnifeNitrous::SecurityGroup.new('nitrous-www')])
      sec_groups.groups.should == [KnifeNitrous::SecurityGroup.new('nitrous-www')]
    end
  end

  describe "#to_a" do
    it 'should return array of groups' do
      sec_groups = KnifeNitrous::SecurityGroups.new([KnifeNitrous::SecurityGroup.new('nitrous-www')])
      sec_groups.to_a.should == [KnifeNitrous::SecurityGroup.new('nitrous-www')]
    end
  end

  describe ".from_hash" do
    let!(:hash) do
      {
        "web" => {
          "rules" => [
            "80 tcp 0.0.0.0/0",
            "443 tcp 0.0.0.0/0",
            "3000-9000 udp 0.0.0.0/0"
          ]
        },
        "ssh" => {
          "rules" => [
            "65100 tcp 0.0.0.0/0"
          ]
        }
      }
    end

    it "should initialize a KnifeNitrous::SecurityGroups object with multiple KnifeNitrous::SecurityGroup objects" do
      security_groups = KnifeNitrous::SecurityGroups.from_hash(hash)
      security_groups.class.should == KnifeNitrous::SecurityGroups
      security_groups.groups.size.should == 2
      security_groups.groups.each { |x| x.class.should == KnifeNitrous::SecurityGroup }
    end
  end
end
