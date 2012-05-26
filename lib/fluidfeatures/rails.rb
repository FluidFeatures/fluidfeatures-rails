
require 'rails'
require 'net/http'
require 'net/http/persistent'

#
# Without these FluidFeatures credentials we cannot talk to
# the FluidFeatures service.
#
%w[FLUIDFEATURES_BASEURI FLUIDFEATURES_SECRET FLUIDFEATURES_APPID].each do |key|
  unless ENV[key]
    raise "Environment variable #{key} expected"
  end
end

module FluidFeatures
  module Rails
    
    #
    # This is called once, when your Rails application fires up.
    # It sets up the before and after request hooks
    #
    def self.initializer
      ::Rails::Application.initializer "fluidfeatures.initializer" do
        ActiveSupport.on_load(:action_controller) do

          @@baseuri = ENV["FLUIDFEATURES_BASEURI"]
          @@secret = ENV["FLUIDFEATURES_SECRET"]
          @@app_id = ENV["FLUIDFEATURES_APPID"]
          @@http = Net::HTTP::Persistent.new 'fluidfeatures'
          @@http.headers['AUTHORIZATION'] = @@secret
          @@unknown_features = {}
          @@last_fetch_duration = nil

          ActionController::Base.append_before_filter :fluidfeatures_request_init
          ActionController::Base.append_after_filter :fluidfeatures_store_features_hit

        end
      end
    end
    
    #
    # This can be used to control how much of your user-base sees a
    # particular feature. It may be easier to use the dashboard provided
    # at https://www.fluidfeatures.com/dashboard to manage this, or to
    # set timers to automate the gradual rollout of your new features.
    #
    def self.feature_set_enabled_percent(feature_name, enabled_percent)
      begin
        uri = URI(@@baseuri + "/app/" + @@app_id.to_s + "/features/" + feature_name.to_s)
        put = Net::HTTP::Put.new uri.path
        put["Content-Type"] = "application/json"
        put["Accept"] = "application/json"
        payload = {
          :enabled => {
            :percent => enabled_percent
          }
        }
        put.body = JSON.dump(payload)
        res = @@http.request uri, put
        if res.is_a?(Net::HTTPSuccess)
          ::Rails.logger.error "[" + res.code.to_s + "] Failed to set feature enabled percent : " + uri.to_s + " : " + res.body.to_s
        end
      rescue Net::HTTP::Persistent::Error
        ::Rails.logger.error "Request to set feature enabled percent failed : " + uri.to_s
      end
    end

    #
    # Returns all the features that FluidFeatures knows about for
    # your application. The enabled percentage (how much of your user-base)
    # sees each feature is also provided.
    #
    def self.get_feature_set
      features = nil
      begin
        uri = URI(@@baseuri + "/app/" + @@app_id.to_s + "/features")
        res = @@http.request uri
        if res.is_a?(Net::HTTPSuccess)
          features = JSON.parse(res.body)
        end
      rescue Net::HTTP::Persistent::Error
        ::Rails.logger.error "Request failed when getting feature set from " + uri.to_s 
      end
      if not features
        ::Rails.logger.error "Empty feature set returned from " + uri.to_s
      end
      features
    end

    #
    # Returns all the features enabled for a specific user.
    # This will depend on the user_id and how many users each
    # feature is enabled for.
    #
    def self.get_user_features(user_id)
      if not user_id
        raise "user_id is not given for get_user_features"
      end
      features = {}
      fetch_start_time = Time.now
      begin
        uri = URI(@@baseuri + "/app/" + @@app_id.to_s + "/user/" + user_id.to_s + "/features")
        res = @@http.request uri
        if res.is_a?(Net::HTTPSuccess)
          features = JSON.parse(res.body)
        else
          ::Rails.logger.error "[" + res.code.to_s + "] Failed to get user features : " + uri.to_s + " : " + res.body.to_s
        end
      rescue Net::HTTP::Persistent::Error
        ::Rails.logger.error "Request to get user features failed : " + uri.to_s
      end
      @@last_fetch_duration = Time.now - fetch_start_time
      features
    end
    
    #
    # This is called when we encounter a feature_name that
    # FluidFeatures has no record of for your application.
    # This will be reported back to the FluidFeatures service so
    # that it can populate your dashboard with this feature.
    # The parameter "default_enabled" is a boolean that says whether
    # this feature should be enabled to all users or no users.
    # Usually, this is "true" for existing features that you are
    # planning to phase out and "false" for new feature that you
    # intend to phase in.
    #
    def self.unknown_feature_hit(feature_name, default_enabled)
      @@unknown_features[feature_name] = default_enabled
    end
    
    #
    # This reports back to FluidFeatures which features we
    # encountered during this request, the request duration,
    # and statistics on time spent talking to the FluidFeatures
    # service. Any new features encountered will also be reported
    # back with the default_enabled status (see unknown_feature_hit)
    # so that FluidFeatures can auto-populate the dashboard.
    #
    def self.log_features_hit(user_id, features_hit, request_duration)
      begin
        uri = URI(@@baseuri + "/app/" + @@app_id.to_s + "/user/" + user_id.to_s + "/features/hit")
        post = Net::HTTP::Post.new uri.path
        post["Content-Type"] = "application/json"
        post["Accept"] = "application/json"
        payload = {
          :stats => {
            :fetch => {
              :duration => @@last_fetch_duration
            },
            :request => {
              :duration => request_duration
            }
          },
          :features => {
            :hit => features_hit
          }
        }
        if @@unknown_features.size
          payload[:features][:unknown] = @@unknown_features
          @@unknown_features = {}
        end
        post.body = JSON.dump(payload)
        res = @@http.request uri, post
        unless res.is_a?(Net::HTTPSuccess)
          ::Rails.logger.error "[" + res.code.to_s + "] Failed to log features hit : " + uri.to_s + " : " + res.body.to_s
        end
      rescue Net::HTTP::Persistent::Error
        ::Rails.logger.error "Request to log user features hit failed : " + uri.to_s
      end
    end
    
  end
end

module ActionController
  class Base
    
    #
    # Here is how we know what your user_id is for the user
    # making the current request.
    # This must be overriden within the user application.
    # We recommend doing this in application_controller.rb
    #
    def fluidfeatures_set_user_id(user_id)
      @ff_user_id = user_id
    end
    
    #
    # This is called by the developer's code to determine if the
    # feature, specified by "feature_name" is enabled for the
    # current user.
    # We call user_id to get the current user's unique id.
    #
    def fluidfeature(feature_name, default_enabled=true)
      @features_hit ||= []
      @features_hit << feature_name
      enabled = default_enabled
      if not @features
        fluidfeatures_retrieve_user_features
      end
      if @features.has_key? feature_name
        enabled = @features[feature_name]
      else
        FluidFeatures::Rails.unknown_feature_hit(feature_name, default_enabled)
      end
      enabled
    end

    #
    # Initialize the FluidFeatures state for this request.
    #
    def fluidfeatures_request_init
      @ff_request_start_time = Time.now
      @features = nil
    end
    
    #
    # Returns the features enabled for this request's user.
    #
    def fluidfeatures_retrieve_user_features
      @features = FluidFeatures::Rails.get_user_features(@ff_user_id)
    end
     
    #
    # After the rails request is complete we will log which features we
    # encountered, including the default settings (eg. enabled) for each
    # feature.
    # This helps the FluidFeatures database prepopulate the feature set
    # without requiring the developer to do it manually.
    # 
    def fluidfeatures_store_features_hit
      if @features
        request_duration = Time.now - @ff_request_start_time
        FluidFeatures::Rails.log_features_hit(@ff_user_id, @features_hit, request_duration)
      end
    end
  end
end

