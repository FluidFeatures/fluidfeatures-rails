# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fluidfeatures/rails/version"

Gem::Specification.new do |s|
  s.name        = "fluidfeatures-rails"
  s.version     = FluidFeatures::Rails::VERSION
  s.authors     = ["Phil Whelan"]
  s.email       = ["phil@fluidfeatures.com"]
  s.homepage    = "https://github.com/BigFastSite/fluidfeatures-rails"
  s.summary     = %q{Ruby on Rails client for the FluidFeatures service.}
  s.description = %q{Ruby on Rails client for the FluidFeatures service.}
  s.rubyforge_project = s.name
  s.files         = `git ls-files`.split("\n")
  #s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
  s.add_dependency "rails", "~>3.0"
end
