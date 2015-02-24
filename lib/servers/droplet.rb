module KnifeNitrous
  class Droplet

    attr_accessor :name, :size, :region, :ssh_keys,
                  :size, :attributes, :run_list 
                 
    def initialize(opts = {})
      load_credentials!

      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end
  end
end
