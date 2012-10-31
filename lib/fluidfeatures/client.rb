
require "logger"

module FluidFeatures
  class Client

    def initialize(base_uri, app_id, secret, options={})

      @logger = options[:logger] || ::Logger.new(STDERR)

      @baseuri = base_uri
      @app_id = app_id
      @secret = secret

      @http = PersistentHTTP.new(
        :name         => 'fluidfeatures',
        :logger       => @logger,
        :pool_size    => 10,
        :warn_timeout => 0.25,
        :force_retry  => true,
        :url          => @baseuri
      )

      @unknown_features = {}
      @last_fetch_duration = nil

    end

    #
    # This can be used to control how much of your user-base sees a
    # particular feature. It may be easier to use the dashboard provided
    # at https://www.fluidfeatures.com/dashboard to manage this, or to
    # set timers to automate the gradual rollout of your new features.
    #
    def feature_set_enabled_percent(feature_name, enabled_percent)
      begin
        uri = URI(@baseuri + "/app/" + @app_id.to_s + "/features/" + feature_name.to_s)
        request = Net::HTTP::Put.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @secret
        payload = {
          :enabled => {
            :percent => enabled_percent
          }
        }
        request.body = JSON.dump(payload)
        response = @http.request uri, request
        if response.is_a?(Net::HTTPSuccess)
          @logger.error "[" + response.code.to_s + "] Failed to set feature enabled percent : " + uri.to_s + " : " + response.body.to_s
        end
      rescue
        @logger.error "Request to set feature enabled percent failed : " + uri.to_s
        raise
      end
    end

    #
    # Returns all the features that FluidFeatures knows about for
    # your application. The enabled percentage (how much of your user-base)
    # sees each feature is also provided.
    #
    def get_feature_set
      features = nil
      begin
        uri = URI(@baseuri + "/app/" + @app_id.to_s + "/features")
        request = Net::HTTP::Get.new uri.path
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @secret
        response = @http.request request
        if response.is_a?(Net::HTTPSuccess)
          features = JSON.parse(response.body)
        end
      rescue
        @logger.error "Request failed when getting feature set from " + uri.to_s
        raise
      end
      if not features
        @logger.error "Empty feature set returned from " + uri.to_s
      end
      features
    end

    #
    # Returns all the features enabled for a specific user.
    # This will depend on the user_id and how many users each
    # feature is enabled for.
    #
    def get_user_features(user)
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
        uri = URI("#{@baseuri}/app/#{@app_id}/user/#{user[:id]}/features")
        uri.query = URI.encode_www_form( attribute_ids )
        url_path = uri.path
        if uri.query
          url_path += "?" + uri.query
        end
        request = Net::HTTP::Get.new url_path
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @secret
        response = @http.request request
        if response.is_a?(Net::HTTPSuccess)
          features = JSON.parse(response.body)
        else
          @logger.error "[#{response.code}] Failed to get user features : #{uri} : #{response.body}"
        end
      rescue
        @logger.error "Request to get user features failed : #{uri}"
        raise
      end
      @last_fetch_duration = Time.now - fetch_start_time
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
    def unknown_feature_hit(feature_name, version_name, defaults)
      if not @unknown_features[feature_name]
        @unknown_features[feature_name] = { :versions => {} }
      end
      @unknown_features[feature_name][:versions][version_name] = defaults
    end
    
    #
    # This reports back to FluidFeatures which features we
    # encountered during this request, the request duration,
    # and statistics on time spent talking to the FluidFeatures
    # service. Any new features encountered will also be reported
    # back with the default_enabled status (see unknown_feature_hit)
    # so that FluidFeatures can auto-populate the dashboard.
    #
    def log_request(user_id, payload)
      begin
        (payload[:stats] ||= {})[:ff_latency] = @last_fetch_duration
        if @unknown_features.size
          (payload[:features] ||= {})[:unknown] = @unknown_features
          @unknown_features = {}
        end
        uri = URI(@baseuri + "/app/#{@app_id}/user/#{user_id}/features/hit")
        request = Net::HTTP::Post.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = @secret
        request.body = JSON.dump(payload)
        response = @http.request request
        unless response.is_a?(Net::HTTPSuccess)
          @logger.error "[" + response.code.to_s + "] Failed to log features hit : " + uri.to_s + " : " + response.body.to_s
        end
      rescue Exception => e
        @logger.error "Request to log user features hit failed : " + uri.to_s
        raise
      end
    end

  end
end
