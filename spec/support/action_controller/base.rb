module ActionController
  class Base
    def self.helper_method(*attrs)
    end

    def cookies
      @cookies ||= {}
    end
  end
end
