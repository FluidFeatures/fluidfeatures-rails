require "spec_helper"
require "fluidfeatures/rails"

describe "FluidFeatures Rails initialization" do
  CONFIG_KEYS = %w[FLUIDFEATURES_BASEURI FLUIDFEATURES_SECRET FLUIDFEATURES_APPID]

  before(:each) do
    CONFIG_KEYS.each {|k| ENV[k] = k}
  end

  it "should start application if Rails defined" do
    defined?(Rails).should be_true
    FluidFeatures::Rails.initializer
    FluidFeatures::Rails.enabled.should be_true
  end

  describe "on :action_controller load" do
    let(:on_load) { ActiveSupport.on_load_block }

    before(:each) do
      $stderr.stub!(:puts)
      FluidFeatures.stub!(:app)
      ActionController::Base.stub!(:append_before_filter)
      ActionController::Base.stub!(:append_after_filter)
      FluidFeatures::Config.stub(:new).and_return({})
      Rails.stub!(:root).and_return(".")
      Rails.stub!(:env).and_return(:development)
      FluidFeatures::Rails.initializer
    end

    it "should create config" do
      FluidFeatures::Config.should_receive(:new).and_return({})
      instance_eval &on_load
    end

    it "should create app with passed credentials" do
      @app = mock("app")
      FluidFeatures.should_receive(:app).with({}).and_return(@app)
      instance_eval &on_load
      FluidFeatures::Rails.ff_app.should == @app
    end

    it "should add :fluidfeatures_request_before to before filter chain" do
      ActionController::Base.should_receive(:append_before_filter).with(:fluidfeatures_request_before)
      instance_eval &on_load
    end

    it "should add :fluidfeatures_request_after to after filter chain" do
      ActionController::Base.should_receive(:append_after_filter).with(:fluidfeatures_request_after)
      instance_eval &on_load
    end
  end
end
