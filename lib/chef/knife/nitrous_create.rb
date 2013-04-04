module KnifeNitrous
  class NitrousCreate < Chef::Knife
    require 'chef/knife/helpers'
    require 'fileutils'

    banner    'knife nitrous create (options)'
    category  'nitrous'

    attr_reader :name, :server_collection

    option  :region,
            short:        '-r REGION',
            long:         '--region REGION',
            description:  'The region you want to create servers in'

    option  :host,
            short:        '-s server',
            long:         '--server server',
            description:  'The specific server you want to create'

    def run
      init_from_nitrous_file!
      config[:host] ? server_collection.set_host! : server_collection.set_regions!
      server_collection.run_chef!
    end

    protected
    def init_from_nitrous_file!

    end

  end
end

