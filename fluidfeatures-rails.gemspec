# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fluidfeatures/rails/version"

Gem::Specification.new do |s|
  s.name        = "fluidfeatures-rails"
  s.version     = FluidFeatures::Rails::VERSION
  s.authors     = ["Phil Whelan"]
  s.email       = ["phil@fluidfeatures.com"]
  s.homepage    = "https://github.com/FluidFeatures/fluidfeatures-rails"
  s.summary     = %q{Ruby on Rails client for the FluidFeatures service.}
  s.description = %q{Ruby on Rails client for the FluidFeatures service.}
  s.rubyforge_project = s.name
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "fluidfeatures", "~>0.4.0" unless ENV["FF_DEV"]

  s.add_development_dependency('rake', '~> 10.0.2')
  s.add_development_dependency('rspec', '~> 2.12.0')
  s.add_development_dependency('guard-rspec', '~> 2.2.1')
  s.add_development_dependency('rb-inotify', '~> 0.8.8')
end
