require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require 'fluidfeatures/rails'

module Testapp
  class Application < Rails::Application
    FluidFeatures::Rails.initializer
  end
end
