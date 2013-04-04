module KnifeNitrous
  class BlockDeviceCollection
    def initialize(block_devices=[])
      @block_devices = []
      block_devices ||= []

      block_devices.each do |obj_or_hash|
        if obj_or_hash.is_a?(Hash)
          @block_devices.push KnifeNitrous::BlockDevice.new(obj_or_hash)
        elsif obj_or_hash.is_a?(KnifeNitrous::BlockDevice)
          @block_devices.push obj_or_hash
        end
      end
    end

    def to_a
      @block_devices
    end

    def size
      @block_devices.size
    end

    def add(obj_or_hash)
      if obj_or_hash.is_a?(Hash)
        @block_devices.push KnifeNitrous::BlockDevice.new(obj_or_hash)
      elsif obj_or_hash.is_a?(KnifeNitrous::BlockDevice)
        @block_devices.push obj_or_hash
      end
    end

    def to_hash
      @block_devices.map(&:to_hash)
    end
  end
end
