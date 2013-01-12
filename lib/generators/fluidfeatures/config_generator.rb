module Fluidfeatures
  class ConfigGenerator < ::Rails::Generators::Base

    CONFIG_FILE = "config/fluidfeatures.yml"

    def create_initializer_file

      if File.file? CONFIG_FILE
        config = YAML.load_file(CONFIG_FILE)
      else
        config = {
          "common" => {
            "base_uri" => "https://www.fluidfeatures.com/service",
            "cache" => {
              "enable" => false,
              "dir" => "tmp/fluidfeatures",
              "limit" => "10MB"
            },
          },
          "development" => {},
          "production" => {},
          "test" => {},
        }
      end

      puts "Enter FluidFeatures credentials [press enter to skip]"
      ["development", "production", "test"].each do |env|
        config[env] ||= {}
        ["app_id", "secret", "base_uri"].each do |key|
          if config[env][key] and config[env][key].size > 0
            default = config[env][key]
          elsif config["common"][key] and config["common"][key].size
            default = config["common"][key]
          end
          print "%s %s %s: " % [
            env,
            key,
            default ? "[#{default}]" : ""
          ]
          value = gets.chomp.strip
          if value and value.size > 0
            config[env][key] = value
          elsif default
            config[env][key] = default
          else
            config[env][key] = nil
          end
        end
        if config[env]["base_uri"] == config["common"]["base_uri"]
          config[env].delete("base_uri")
        end
      end

      yaml = YAML.dump(config)
      # remove "---" at top
      yaml.sub!(/^---\r?\n/, "")
      # add extra line between environments
      yaml.gsub!(/(\r?\n)(\S)/) {|m| $1 + $1 + $2 }

      create_file CONFIG_FILE, yaml
    end
  end
end
