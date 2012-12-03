require "spec_helper"
require "fluidfeatures/rails/config/routes"

describe "FluidFeatures routes" do
  let(:routes) { Rails::Routes.routes_block }

  it "should be added for feature by name" do
    stub!(:match)
    should_receive(:match).with("/fluidfeature/:feature_name"=> "fluid_feature_ajax#index")
    instance_eval &routes
  end

  it "should be added for goal by name" do
    stub!(:match)
    should_receive(:match).with("/fluidgoal/:goal_name" => "fluid_goal_ajax#index")
    instance_eval &routes
  end

  it "should be added for goal by name and version" do
    stub!(:match)
    should_receive(:match).with("/fluidgoal/:goal_name/:goal_version" => "fluid_goal_ajax#index")
    instance_eval &routes
  end
end
