require 'spec_helper'
require 'fakeweb'
require 'yajl'
require 'json_spec'

describe HomeController do

  describe '#index' do

    before do
      FakeWeb.register_uri(
        :get,
        File.join(ENV["FLUIDFEATURES_BASEURI"], "/app/123/user/1/features"),
        :body => Yajl::Encoder.encode({}) # no features registered yet
      )
      FakeWeb.register_uri(
        :get,
        File.join(ENV["FLUIDFEATURES_BASEURI"], "/app/123/user/2/features"),
        :body => Yajl::Encoder.encode({
          :apples => false, 
          :oranges => true, 
          :lemons => true
        })
      )
      [1,2].each do |user_id|
        FakeWeb.register_uri(
          :post,
          File.join(ENV["FLUIDFEATURES_BASEURI"], "/app/123/user/#{user_id.to_s}/features/hit"),
          :body => ""
        )
      end
    end

    it 'should return only the default enabled features for user 1' do
      get :index, { :user_id => 1 }
      response.response_code.should == 200
      response.body.should == "apples"

      # Check the call to features hit
      features_hit_request = FakeWeb.last_request
      JsonSpec.exclude_keys("duration")
      features_hit_request.body.should be_json_eql(%({
        "features": {
          "hit": [
            "apples",
            "oranges",
            "lemons"
          ],
          "unknown": {
            // features that we have not seen before
            "apples": {
              "versions": {
                "1": {
                  "enabled": true
                }
              }
            },
            "lemons": {
              "versions": {
                "1": {
                  "enabled": false
                }
              }
            },
            "oranges": {
              "versions": {
                "1": {
                  "enabled": false
                }
              }
            }
          }
        },
        "stats": {
          "fetch": {
            // duration ignored
          },
          "request": {
            // duration ignored
          }
        }
      }))
    end

    it 'should not return the feature for user 2' do
      get :index, { :user_id => 2 }
      response.response_code.should == 200
      response.body.should == "oranges lemons"

      # Check the call to features hit
      features_hit_request = FakeWeb.last_request
      JsonSpec.exclude_keys("duration")
      features_hit_request.body.should be_json_eql(%({
        "features": {
          "hit": [
            "apples",
            "oranges",
            "lemons"
          ],
          "unknown": {
            // no unknown features
          }
        },
        "stats": {
          "fetch": {
            // duration ignored
          },
          "request": {
            // duration ignored
          }
        }
      }))
    end

  end

end

