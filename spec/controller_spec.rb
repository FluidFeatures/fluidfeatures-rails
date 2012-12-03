require "spec_helper"
require "fluidfeatures/rails/app/controllers/fluidfeatures_controller"

describe "FluidFeatures Features controller" do
  let(:controller) { FluidFeatureAjaxController.new }

  it "should call #fluidfeature and render on index" do
    controller.update_params(feature_name: "Feature", version_name: "a")
    controller.should_receive(:fluidfeature).with("Feature", "a")
    controller.should_receive(:render)
    controller.index
  end
end

describe "FluidFeatures Goals controller" do
  let(:controller) { FluidGoalAjaxController.new }

  it "should call #fluidgoal and render on index" do
    controller.update_params(goal_name: "Goal", goal_version: "default")
    controller.should_receive(:fluidgoal).with("Goal", "default")
    controller.should_receive(:render)
    controller.index
  end
end