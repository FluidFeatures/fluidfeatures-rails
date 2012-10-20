
if RUBY_VERSION < "1.9.2"
  require "pre_ruby192/uri"
end

module FluidFeatures
  module Rails

    class << self
      attr_accessor :enabled
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

          @@baseuri = ENV["FLUIDFEATURES_BASEURI"]
          @@secret = ENV["FLUIDFEATURES_SECRET"]
          @@app_id = ENV["FLUIDFEATURES_APPID"]
          @@http = PersistentHTTP.new(
            :name         => 'fluidfeatures',
            :logger       => ::Rails.logger,
            :pool_size    => 10,
            :warn_timeout => 0.25,
            :force_retry  => true,
            :url          => @@baseuri
          )
          @@unknown_features = {}
          @@last_fetch_duration = nil

          ActionController::Base.append_before_filter :fluidfeatures_request_before
          ActionController::Base.append_after_filter  :fluidfeatures_request_after

        end
      end

      @enabled = true
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
        request = Net::HTTP::Put.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @@secret
        payload = {
          :enabled => {
            :percent => enabled_percent
          }
        }
        request.body = JSON.dump(payload)
        response = @@http.request uri, request
        if response.is_a?(Net::HTTPSuccess)
          ::Rails.logger.error "[" + response.code.to_s + "] Failed to set feature enabled percent : " + uri.to_s + " : " + response.body.to_s
        end
      rescue
        ::Rails.logger.error "Request to set feature enabled percent failed : " + uri.to_s
        raise
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
        request = Net::HTTP::Get.new uri.path
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @@secret
        response = @@http.request request
        if response.is_a?(Net::HTTPSuccess)
          features = JSON.parse(response.body)
        end
      rescue
        ::Rails.logger.error "Request failed when getting feature set from " + uri.to_s
        raise
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
    def self.get_user_features(user)

      if not user
        raise "user object should be a Hash"
      end
      if not user[:id]
        raise "user does not contain :id field"
      end

      # extract just attribute ids into simple hash
      attribute_ids = {
        :anonymous => !!user[:anonymous]
      }
      [:unique, :cohorts].each do |attr_type|
        if user.has_key? attr_type
          user[attr_type].each do |attr_key, attr|
            if attr.is_a? Hash
              if attr.has_key? :id
                attribute_ids[attr_key] = attr[:id]
              end
            else
              attribute_ids[attr_key] = attr
            end
          end
        end
      end

      # normalize attributes ids as strings
      attribute_ids.each do |attr_key, attr_id|
        if attr_id.is_a? FalseClass or attr_id.is_a? TrueClass
          attribute_ids[attr_key] = attr_id.to_s.downcase
        elsif not attr_id.is_a? String
          attribute_ids[attr_key] = attr_id.to_s
        end
      end

      features = {}
      fetch_start_time = Time.now
      begin
        uri = URI("#{@@baseuri}/app/#{@@app_id}/user/#{user[:id]}/features")
        uri.query = URI.encode_www_form( attribute_ids )
        url_path = uri.path
        if uri.query
          url_path += "?" + uri.query
        end
        request = Net::HTTP::Get.new url_path
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @@secret
        $stderr.puts "GET #{uri}"
        response = @@http.request request
        if response.is_a?(Net::HTTPSuccess)
          features = JSON.parse(response.body)
        else
          ::Rails.logger.error "[#{response.code}] Failed to get user features : #{uri} : #{response.body}"
        end
      rescue
        ::Rails.logger.error "Request to get user features failed : #{uri}"
        raise
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
    def self.unknown_feature_hit(feature_name, version_name, defaults)
      if not @@unknown_features[feature_name]
        @@unknown_features[feature_name] = { :versions => {} }
      end
      @@unknown_features[feature_name][:versions][version_name] = defaults
    end
    
    #
    # This reports back to FluidFeatures which features we
    # encountered during this request, the request duration,
    # and statistics on time spent talking to the FluidFeatures
    # service. Any new features encountered will also be reported
    # back with the default_enabled status (see unknown_feature_hit)
    # so that FluidFeatures can auto-populate the dashboard.
    #
    def self.log_request(user_id, payload)
      begin
        (payload[:stats] ||= {})[:ff_latency] = @@last_fetch_duration
        if @@unknown_features.size
          (payload[:features] ||= {})[:unknown] = @@unknown_features
          @@unknown_features = {}
        end
        uri = URI(@@baseuri + "/app/#{@@app_id}/user/#{user_id}/features/hit")
        request = Net::HTTP::Post.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @@secret
        request.body = JSON.dump(payload)
        response = @@http.request request
        unless response.is_a?(Net::HTTPSuccess)
          ::Rails.logger.error "[" + response.code.to_s + "] Failed to log features hit : " + uri.to_s + " : " + response.body.to_s
        end
      rescue Exception => e
        ::Rails.logger.error "Request to log user features hit failed : " + uri.to_s
        raise
      end
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
        FluidFeatures::Rails.unknown_feature_hit(feature_name, version_name, options)
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
      @ff_features = FluidFeatures::Rails.get_user_features(user)
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
      FluidFeatures::Rails.log_request(fluidfeatures_user[:id], payload)
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

