module KnifeNitrous
  class BlockDevice
    attr_accessor :name, :snapshot_id, :size, :delete_on_termination

    def initialize(attrs={})
      attrs.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def to_hash
      {
        'DeviceName' => self.name,
        'Ebs.SnapshotId' => self.snapshot_id,
        'Ebs.VolumeSize' => self.size,
        'Ebs.DeleteOnTermination' => "#{self.delete_on_termination}"
      }
    end
  end
end
