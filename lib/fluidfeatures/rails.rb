
require "fluidfeatures/client"

module FluidFeatures
  module Rails

    class << self
      attr_accessor :enabled
      attr_accessor :client
    end
    
    #
    # This is called once, when your Rails application fires up.
    # It sets up the before and after request hooks
    #
    def self.initializer

      #
      # Without these FluidFeatures credentials we cannot talk to
      # the FluidFeatures service.
      #
      %w[FLUIDFEATURES_BASEURI FLUIDFEATURES_SECRET FLUIDFEATURES_APPID].each do |key|
        unless ENV[key]
          $stderr.puts "!! fluidfeatures-rails requires ENV[\"#{key}\"] (fluidfeatures is disabled)"
          return
        end
      end
      unless defined? ::Rails
        $stderr.puts "!! fluidfeatures-rails requires rails (fluidfeatures is disabled)"
        return
      end
      $stderr.puts "=> fluidfeatures-rails initializing as app #{ENV["FLUIDFEATURES_APPID"]} with #{ENV["FLUIDFEATURES_BASEURI"]}"


      require 'net/http'
      require 'persistent_http'

      ::Rails::Application.initializer "fluidfeatures.initializer" do
        ActiveSupport.on_load(:action_controller) do
          api_baseuri = ENV["FLUIDFEATURES_BASEURI"]
          api_appid   = ENV["FLUIDFEATURES_APPID"]
          api_secret  = ENV["FLUIDFEATURES_SECRET"]

          ::FluidFeatures::Rails.client = ::FluidFeatures::Client.new(
            api_baseuri,
            api_appid,
            api_secret,
            # options
            {
              :logger => nil,#::Rails.logger
            }
          )

          ActionController::Base.append_before_filter :fluidfeatures_request_before
          ActionController::Base.append_after_filter  :fluidfeatures_request_after
        end
      end

      @enabled = true
    end
    
  end
end

module ActionController
  class Base
    
    # allow fluidfeature to be called from templates
    helper_method :fluidfeature

    #
    # Here is how we know what your user_id is for the user
    # making the current request.
    # This must be overriden within the user application.
    # We recommend doing this in application_controller.rb
    #
    def fluidfeatures_initialize_user

      # TODO: Do not always get verbose user details.
      #       Get for new users and then less frequently.
      user = fluidfeature_current_user(verbose=true)

      if user[:id] and not user[:anonymous]
        # We are no longer an anoymous users. Delete the cookie
        if cookies.has_key? :fluidfeatures_anonymous
          cookies.delete(:fluidfeatures_anonymous)
        end
      else
        # We're an anonymous user
        user[:anonymous] = true

        # if we were not given a user[:id] for this anonymous user, then get
        # it from an existing cookie or create a new one.
        unless user[:id]
          # Have we seen them before?
          if cookies.has_key? :fluidfeatures_anonymous
            user[:id] = cookies[:fluidfeatures_anonymous]
          else
            # Create new cookie. Use rand + micro-seconds of current time
            user[:id] = "anon-" + Random.rand(9999999999).to_s + "-" + ((Time.now.to_f * 1000000).to_i % 1000000).to_s
          end
        end
        # update the cookie, with whatever the user[:id] has been set to
        cookies[:fluidfeatures_anonymous] = user[:id]
      end
      user[:anonymous] = !!user[:anonymous]
      @ff_user = user
    end

    def fluidfeatures_user
      unless @ff_user
        fluidfeatures_initialize_user
      end
      @ff_user
    end

    #
    # This is called by the developer's code to determine if the
    # feature, specified by "feature_name" is enabled for the
    # current user.
    # We call user_id to get the current user's unique id.
    #
    def fluidfeature(feature_name, defaults={})
      if defaults === true or defaults === false
        defaults = { :enabled => defaults }
      end
      unless ::FluidFeatures::Rails.enabled
        return defaults[:enabled] || false
      end
      global_defaults = fluidfeatures_defaults || {}
      version_name = (defaults[:version] || global_defaults[:version]).to_s
      if not @ff_features
        fluidfeatures_retrieve_user_features
      end
      if @ff_features.has_key? feature_name
        if @ff_features[feature_name].is_a? FalseClass or @ff_features[feature_name].is_a? TrueClass
          enabled = @ff_features[feature_name]
        elsif @ff_features[feature_name].is_a? Hash
          if @ff_features[feature_name].has_key? version_name
            enabled = @ff_features[feature_name][version_name]
          end
        end
      end
      if enabled === nil
        enabled = defaults[:enabled] || global_defaults[:enabled]
        
        # Tell FluidFeatures about this amazing new feature...
        options = Hash.new(defaults)
        options[:enabled] = enabled
        if options.has_key? :version
          options.remove(:version)
        end
        ::Rails.logger.debug "fluidfeature: seeing feature '#{feature_name.to_s}' (version '#{version_name.to_s}') for the first time."
        ::FluidFeatures::Rails.client.unknown_feature_hit(feature_name, version_name, options)
      end
      if enabled
        @ff_features_hit[feature_name] ||= {}
        @ff_features_hit[feature_name][version_name.to_s] = {}
      end
      enabled
    end

    def fluidgoal(goal_name, defaults={})
      global_defaults = fluidfeatures_defaults || {}
      version_name = (defaults[:version] || global_defaults[:version]).to_s
      @ff_goals_hit[goal_name] ||= {}
      @ff_goals_hit[goal_name][version_name.to_s] = {}
    end

    #
    # Initialize the FluidFeatures state for this request.
    #
    def fluidfeatures_request_before
      @ff_request_start_time = Time.now
      @ff_features = nil
      @ff_features_hit = {}
      @ff_goals_hit = {}
    end
    
    #
    # Returns the features enabled for this request's user.
    #
    def fluidfeatures_retrieve_user_features
      user = fluidfeatures_user
      @ff_features = ::FluidFeatures::Rails.client.get_user_features(user)
    end
     
    #
    # After the rails request is complete we will log which features we
    # encountered, including the default settings (eg. enabled) for each
    # feature.
    # This helps the FluidFeatures database prepopulate the feature set
    # without requiring the developer to do it manually.
    # 
    def fluidfeatures_request_after
      request_duration = Time.now - @ff_request_start_time
      url = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
      payload = {
        :user => {
          :id => fluidfeatures_user[:id]
        },
        :stats => {
          :request => {
            :duration => request_duration
          }
        },
        :hits => {
          :feature => @ff_features_hit,
          :goal    => @ff_goals_hit
        },
        :url => url
      }
      [:name, :anonymous, :unique, :cohorts].each do |key|
        if fluidfeatures_user[key]
          (payload[:user] ||= {})[key] = fluidfeatures_user[key]
        end
      end
      ::FluidFeatures::Rails.client.log_request(fluidfeatures_user[:id], payload)
    end
    
    def fluidfeatures_defaults
      # By default unknown features are disabled.
      {
        :enabled => false,
        :version => :default
      }
    end

  end
end

