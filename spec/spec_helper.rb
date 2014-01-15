require 'knife-nitrous'

require 'rspec'
require 'fakefs/safe'
require 'fakefs/spec_helpers'


['contexts', 'helpers', 'matchers'].each do |dir|
  Dir[File.expand_path(File.join(File.dirname(__FILE__),dir,'*.rb'))].each {|f| require f}
end

RSpec.configure do |c|
  c.include CloudHelpers
  c.before(:all) do
    Fog.mock!

    # Disable logging to console and HipChat.
    module Chef::Knife::NitrousBase
      def announce(message, level: level); end
    end
  end
end

