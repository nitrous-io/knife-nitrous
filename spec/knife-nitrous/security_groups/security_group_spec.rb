require 'spec_helper'

describe KnifeNitrous::SecurityGroup do
  describe 'initialize' do
    it 'should initialize all the instance variables' do
      group = KnifeNitrous::SecurityGroup.new('nitrous-www')
      group.name.should == 'nitrous-www'
    end
  end

  describe "#provision" do
    let!(:rule_1) { KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '3000-9000') }
    let!(:rule_2) { KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '443') }
    let!(:rule_3) { KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: 'web', ports: '65100') }

    let!(:sg)     { KnifeNitrous::SecurityGroup.new('nitrous-www') }

    let!(:region) { 'ap-southeast-1' }

    before :all do
      sg.add_rule rule_1
      sg.add_rule rule_2
      sg.add_rule rule_3

      ENV['AWS_ACCESS_KEY_ID'] = 'aws_access_key_id'
      ENV['AWS_SECRET_ACCESS_KEY'] = 'aws_secret_access_key'
    end

    after :all do
      ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
    end

    context "security group already exists in AWS" do
      context "rules in the SecurityGroup object already exist in AWS" do
        before :all do
          dup_rule_1 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '3000-9000')
          dup_rule_2 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '443')

          dup_sg     = KnifeNitrous::SecurityGroup.new('nitrous-www')
          dup_sg.add_rule dup_rule_1
          dup_sg.add_rule dup_rule_2

          @dup_aws_security_group = dup_sg.provision(region)
          @aws_security_group = sg.provision(region)
        end

        after :all do
          @dup_aws_security_group.destroy
        end

        it "should be a Fog::Compute::AWS::SecurityGroup object" do
          @aws_security_group.class.should == Fog::Compute::AWS::SecurityGroup
        end

        it "should have the name and description set to the name of the security group" do
          @aws_security_group.name.should == 'nitrous-www'
          @aws_security_group.description.should == 'nitrous-www'
        end

        it "should have the rules set correctly" do
          @aws_security_group.ip_permissions.size.should == 3

          rule_1, rule_2, rule_3 = @aws_security_group.ip_permissions

          rule_1['ipProtocol'].should == 'tcp'
          rule_1['fromPort'].should == 3000
          rule_1['toPort'].should == 9000
          rule_1['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

          rule_2['ipProtocol'].should == 'tcp'
          rule_2['fromPort'].should == 443
          rule_2['toPort'].should == 443
          rule_2['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

          rule_3['ipProtocol'].should == 'tcp'
          rule_3['fromPort'].should == 65100
          rule_3['toPort'].should == 65100
          rule_3['groups'].first['groupName'].should == 'web'
          rule_3['groups'].first['userId'].should == @aws_security_group.owner_id
        end
      end

      context "rules in the SecurityGroup object do not exist in AWS" do
        before :all do
          dup_rule_1 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '3000-9000')
          dup_rule_2 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '443')
          dup_rule_3 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: 'web', ports: '65100')
          dup_rule_4 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: 'web_1', ports: '65100')
          dup_rule_5 = KnifeNitrous::SecurityRule.new(protocol: 'tcp', source: '0.0.0.0/0', ports: '80-100')

          dup_sg     = KnifeNitrous::SecurityGroup.new('nitrous-www')
          dup_sg.add_rule dup_rule_1
          dup_sg.add_rule dup_rule_2
          dup_sg.add_rule dup_rule_3
          dup_sg.add_rule dup_rule_4
          dup_sg.add_rule dup_rule_5

          @dup_aws_security_group = dup_sg.provision(region)
          @aws_security_group = sg.provision(region)
        end

        after :all do
          @dup_aws_security_group.destroy
        end

        it "should be a Fog::Compute::AWS::SecurityGroup object" do
          @aws_security_group.class.should == Fog::Compute::AWS::SecurityGroup
        end

        it "should have the name and description set to the name of the security group" do
          @aws_security_group.name.should == 'nitrous-www'
          @aws_security_group.description.should == 'nitrous-www'
        end

        it "should remove the rules from AWS" do
          @aws_security_group.ip_permissions.size.should == 3

          rule_1, rule_2, rule_3 = @aws_security_group.ip_permissions

          rule_1['ipProtocol'].should == 'tcp'
          rule_1['fromPort'].should == 3000
          rule_1['toPort'].should == 9000
          rule_1['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

          rule_2['ipProtocol'].should == 'tcp'
          rule_2['fromPort'].should == 443
          rule_2['toPort'].should == 443
          rule_2['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

          rule_3['ipProtocol'].should == 'tcp'
          rule_3['fromPort'].should == 65100
          rule_3['toPort'].should == 65100
          rule_3['groups'].first['groupName'].should == 'web'
          rule_3['groups'].first['userId'].should == @aws_security_group.owner_id
        end
      end
    end

    context "security group does not exist in AWS" do
      before do
        @aws_security_group = sg.provision(region)
      end

      after do
        @aws_security_group.destroy
      end

      it "should be a Fog::Compute::AWS::SecurityGroup object" do
        @aws_security_group.class.should == Fog::Compute::AWS::SecurityGroup
      end

      it "should have the name and description set to the name of the security group" do
        @aws_security_group.name.should == 'nitrous-www'
        @aws_security_group.description.should == 'nitrous-www'
      end

      it "should have the rules set correctly" do
      @aws_security_group.ip_permissions.size.should == 3
        rule_1, rule_2, rule_3 = @aws_security_group.ip_permissions

        rule_1['ipProtocol'].should == 'tcp'
        rule_1['fromPort'].should == 3000
        rule_1['toPort'].should == 9000
        rule_1['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

        rule_2['ipProtocol'].should == 'tcp'
        rule_2['fromPort'].should == 443
        rule_2['toPort'].should == 443
        rule_2['ipRanges'].first['cidrIp'].should == '0.0.0.0/0'

        rule_3['ipProtocol'].should == 'tcp'
        rule_3['fromPort'].should == 65100
        rule_3['toPort'].should == 65100
        rule_3['groups'].first['groupName'].should == 'web'
        rule_3['groups'].first['userId'].should == @aws_security_group.owner_id
      end
    end
  end

  describe ".from_hash" do
    let!(:hash) do
      {
        "name" => "root-www",
        "rules" => [
          "80 tcp 0.0.0.0/0",
          "443 tcp 0.0.0.0/0",
          "65100 tcp 0.0.0.0/0",
          "3000-9000 udp 0.0.0.0/0"
        ]
      }
    end

    it "should initialize a KnifeNitrous::SecurityGroup object with all the rules initialized" do
      security_group = KnifeNitrous::SecurityGroup.from_hash(hash)

      security_group.class.should == KnifeNitrous::SecurityGroup
      security_group.name.should == 'root-www'
      security_group.rules.size.should == 4

      rules = security_group.rules

      rules[0].protocol.should == 'tcp'
      rules[0].ports.should == '80'
      rules[0].source.should == '0.0.0.0/0'

      rules[1].protocol.should == 'tcp'
      rules[1].ports.should == '443'
      rules[1].source.should == '0.0.0.0/0'

      rules[2].protocol.should == 'tcp'
      rules[2].ports.should == '65100'
      rules[2].source.should == '0.0.0.0/0'

      rules[3].protocol.should == 'udp'
      rules[3].ports.should == '3000-9000'
      rules[3].source.should == '0.0.0.0/0'
    end
  end
end
