ENV["RAILS_ENV"] ||= 'test'

ENV["FLUIDFEATURES_BASEURI"] ||= "http://www.fluidfeatures.com/service"
ENV["FLUIDFEATURES_APPID"] ||= "123"
ENV["FLUIDFEATURES_SECRET"] ||= "ssssshhhhhh"

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
