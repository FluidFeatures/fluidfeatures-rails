module Fluidfeatures
  class ConfigGenerator < ::Rails::Generators::Base

    CONFIG_FILE = "config/fluidfeatures.yml"

    def create_initializer_file

      puts "Enter FluidFeatures credentials [press enter to skip]"
      print "development app_id: "
      dev_app_id = gets.chomp

      print "development secret: "
      dev_secret = gets.chomp

      print "production app_id: "
      prod_app_id = gets.chomp

      print "production secret: "
      prod_secret = gets.chomp

      print "test app_id: "
      test_app_id = gets.chomp

      print "test secret: "
      test_secret = gets.chomp

      puts "Warning: production app_id and secret have not been set in #{CONFIG_FILE}"

      create_file CONFIG_FILE, """
common:
  base_uri: https://www.fluidfeatures.com/service
  cache:
    enable: false
    dir: tmp/fluidfeatures
    limit: 2mb

development:
  app_id: #{dev_app_id}
  secret: #{dev_secret}

test:
  app_id: #{test_app_id}
  secret: #{test_secret}

production:
  app_id: #{prod_app_id}
  secret: #{prod_secret}
"""
    end
  end
end
