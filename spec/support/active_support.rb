class ActiveSupport
  def self.on_load(name, &block)
    @@on_load_block = block
  end

  def self.on_load_block
    @@on_load_block
  end
end