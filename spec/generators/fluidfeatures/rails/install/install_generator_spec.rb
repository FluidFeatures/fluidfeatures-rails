require "spec_helper"
require "generators/fluid_features/rails/install/install_generator"

describe FluidFeatures::Rails::Generators::InstallGenerator do
  it "creates a configuration file" do
    subject.should_receive(:create_file).with("config/fluidfeatures.yml", kind_of(String))
    subject.create_initializer_file
  end
end
