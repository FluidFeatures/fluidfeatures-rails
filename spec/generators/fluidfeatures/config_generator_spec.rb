require "spec_helper"
require "generators/fluidfeatures/config_generator"

describe Fluidfeatures::ConfigGenerator do
  it "creates a configuration file" do
    subject.should_receive(:create_file).with("config/fluidfeatures.yml", kind_of(String))
    subject.create_initializer_file
  end
end
