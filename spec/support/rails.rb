module Rails
  class Routes
    def draw(&block)
      @@routes_block = block
    end

    def self.routes_block
      @@routes_block
    end
  end

  class Application
    def routes
      Routes.new
    end

    def self.initializer(initializer_name, &block)
      block.call
    end
  end

  def self.application
    Application.new
  end

  def self.logger
    @@logger ||= Object.new
  end
end