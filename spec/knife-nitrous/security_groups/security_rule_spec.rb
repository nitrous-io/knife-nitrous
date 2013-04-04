require 'spec_helper'

describe KnifeNitrous::SecurityRule do
  describe "initialize" do
    it "should initialize all the instance variables" do
      rule = KnifeNitrous::SecurityRule.new(ports: '22', protocol: 'tcp', source: '127.0.0.1')
      rule.ports.should == '22'
      rule.protocol.should == 'tcp'
      rule.source.should == '127.0.0.1'
    end
  end

  describe "#belongs_to_another_account?" do
    it "should true if the source is an IP" do
      rule_1 = KnifeNitrous::SecurityRule.new(ports: '22', protocol: 'tcp', source: 'heroku_account_id:heroku_group_id')
      rule_1.belongs_to_another_account?.should be_true

      rule_2 = KnifeNitrous::SecurityRule.new(ports: '3000-9000', protocol: 'tcp', source: 'bombay')
      rule_2.belongs_to_another_account?.should be_false
    end
  end

  describe "#port_range" do
    it "should return the port range as a range" do
      rule_1 = KnifeNitrous::SecurityRule.new(ports: '22', protocol: 'tcp', source: '127.0.0.1')
      rule_1.port_range.should == (22..22)

      rule_2 = KnifeNitrous::SecurityRule.new(ports: '3000-9000', protocol: 'tcp', source: 'bombay')
      rule_2.port_range.should == (3000..9000)
    end
  end

  describe "#is_source_ip?" do
    it "should true if the source is an IP" do
      rule_1 = KnifeNitrous::SecurityRule.new(ports: '22', protocol: 'tcp', source: '127.0.0.1')
      rule_1.is_source_ip?.should be_true

      rule_2 = KnifeNitrous::SecurityRule.new(ports: '3000-9000', protocol: 'tcp', source: 'bombay')
      rule_2.is_source_ip?.should be_false
    end
  end

  describe "#source" do
    it "should return a hash with the key as the owner_id and the value as the group_id" do
      rule_1 = KnifeNitrous::SecurityRule.new(ports: '22', protocol: 'tcp', source: 'heroku_account_id:heroku_group_id')
      rule_1.source.should == { 'heroku_account_id' => 'heroku_group_id' }

      rule_2 = KnifeNitrous::SecurityRule.new(ports: '3000-9000', protocol: 'tcp', source: 'bombay')
      rule_2.source.should == 'bombay'

      rule_3 = KnifeNitrous::SecurityRule.new(ports: '3000-9000', protocol: 'tcp', source: '127.0.0.1')
      rule_3.source.should == '127.0.0.1'
    end
  end

  describe "#source=" do
    it "should clean up the source of spaces" do
      rule_1 = KnifeNitrous::SecurityRule.new(source: '0.0.0.0/0')
      rule_1.source.should == '0.0.0.0/0'
      rule_2 = KnifeNitrous::SecurityRule.new(source: 'abcdef')
      rule_2.source.should == 'abcdef'
      rule_3 = KnifeNitrous::SecurityRule.new(source: 'abcdef,xyz123')
      rule_3.source.should == 'abcdef,xyz123'
      rule_4 = KnifeNitrous::SecurityRule.new(source: 'abcdef, xyz123')
      rule_4.source.should == 'abcdef,xyz123'
    end
  end

  describe ".parse" do
    it "should return a SecurityRule object with the instance variables set" do
      rule = KnifeNitrous::SecurityRule.parse("443 tcp 0.0.0.0/0")
      rule.class.should == KnifeNitrous::SecurityRule
      rule.ports.should == "443"
      rule.source.should == "0.0.0.0/0"
      rule.protocol.should == "tcp"
    end
  end

end
