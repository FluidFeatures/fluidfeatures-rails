require "spec_helper"
require "fluidfeatures/rails"

describe "FluidFeatures controller extensions" do

  let(:controller) { class DummyController < ActionController::Base; end; DummyController.new }

  let(:transaction) { mock('transaction', user: mock('user')) }

  context "API calls" do

    before(:each) do
      FluidFeatures::Rails.stub!(:enabled).and_return(true)
      controller.ff_transaction = transaction
    end

    it "#fluidfeature should call #feature_enabled? on transaction" do
      params = ["Feature", "a", true]
      controller.ff_transaction.should_receive(:feature_enabled?).with(*params)
      controller.fluidfeature(*params)
    end

    it "#fluidfeature should call #feature_enabled? on transaction without version" do
      controller.ff_transaction.should_receive(:feature_enabled?).with("Feature", nil, true)
      controller.fluidfeature("Feature", true)
    end

    it "#fluidgoal should call #goal_hit on transaction" do
      controller.ff_transaction.should_receive(:goal_hit).with("Goal", nil)
      controller.fluidgoal("Goal")
    end

  end

  context "#fluidfeatures_initialize_user" do

    before(:each) do
      transaction.user.stub!(:anonymous).and_return(true)
      transaction.user.stub!(:unique_id).and_return("unique id")
      controller.stub!(:fluidfeatures_current_user).and_return({})
      controller.cookies.stub!(:[]).with(:fluidfeatures_anonymous).and_return("anonymous id")
      controller.stub!(:request).and_return(mock("request", protocol: 'http://', host_with_port: 'example.com', fullpath: '/'))
      FluidFeatures::Rails.ff_app = mock('app')
      FluidFeatures::Rails.ff_app.stub!(:user_transaction).and_return(transaction)
    end

    it "should log error if not #fluidfeature_current_user defined" do
      controller.unstub!(:fluidfeatures_current_user)
      Rails.logger.should_receive(:error).with("[FF] Method fluidfeatures_current_user is not defined in your ApplicationController")
      controller.fluidfeatures_initialize_user.should == nil
    end

    it "should get user id from cookies if not set" do
      controller.cookies.should_receive(:[]).with(:fluidfeatures_anonymous).and_return("anonymous id")
      controller.fluidfeatures_initialize_user
    end

    it "should update cookie for anonymous user" do
      controller.cookies.should_receive(:[]=).with(:fluidfeatures_anonymous, "unique id")
      controller.fluidfeatures_initialize_user
    end

    it "should delete cookie for existing user" do
      transaction.user.stub!(:anonymous).and_return(false)
      controller.cookies.stub!(:has_key?).with(:fluidfeatures_anonymous).and_return(true)
      controller.cookies.should_receive(:delete).with(:fluidfeatures_anonymous)
      controller.fluidfeatures_initialize_user
    end

    it "should call #user_transaction on app with valid params" do
      FluidFeatures::Rails.ff_app.should_receive(:user_transaction).with("anonymous id", "http://example.com/", nil, false, nil, nil)
      controller.fluidfeatures_initialize_user
    end

  end

  it "#fluidfeatures_request_before should initialize user transaction" do
    transaction = mock("transaction")
    controller.should_receive(:fluidfeatures_initialize_user).and_return(transaction)
    controller.fluidfeatures_request_before
    controller.ff_transaction.should == transaction
  end

  it "#fluidfeatures_request_after should end transaction" do
    controller.ff_transaction = mock("transaction")
    controller.ff_transaction.should_receive(:end_transaction)
    controller.fluidfeatures_request_after
  end

  it "#fluidfeatures_retrieve_user_features should return user transaction features" do
    features = []
    controller.ff_transaction = mock("transaction")
    controller.ff_transaction.should_receive(:features).and_return(features)
    controller.fluidfeatures_retrieve_user_features.should eq(features)
  end
end
