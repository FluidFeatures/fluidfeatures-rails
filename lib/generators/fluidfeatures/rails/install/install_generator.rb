module FluidFeatures
  module Rails
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        def create_initializer_file
          create_file "config/fluidfeatures.yml", "common:
  baseuri: https://www.fluidfeatures.com/service
  cache:
    enable: false
    dir: tmp/fluidfeatures
    limit: 2mb

development:
  appid:
  secret:

test:
  appid:
  secret:

production:
  appid:
  secret:
"
        end
      end
    end
  end
end
