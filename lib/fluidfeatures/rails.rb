require "fluidfeatures"

module FluidFeatures
  module Rails

    class << self
      attr_accessor :enabled
      attr_accessor :ff_app
    end

    #
    # This is called once, when your Rails application fires up.
    # It sets up the before and after request hooks
    #
    def self.initializer

      @enabled = false

      # Initialize
      ::Rails::Application.initializer "fluidfeatures.initializer" do
        ActiveSupport.on_load(:action_controller) do

          # Without these FluidFeatures credentials we cannot talk to
          # the FluidFeatures service.
          is_configured = true
          ff_config_path = "#{::Rails.root}/config/fluidfeatures.yml"
          unless File.file? ff_config_path
            %w[FLUIDFEATURES_BASEURI FLUIDFEATURES_SECRET FLUIDFEATURES_APPID].each do |key|
              is_configured &= ENV[key]
            end
          end
          unless is_configured
            $stderr.puts "fluidfeatures-rails is not configured. Run 'rails g fluidfeatures:config'"
            break
          end

          if File.file? ff_config_path
            config = ::FluidFeatures::Config.new(ff_config_path, ::Rails.env)
          else
            config = ::FluidFeatures::Config.new({
              "base_uri" => ENV["FLUIDFEATURES_BASEURI"],
              "app_id"   => ENV["FLUIDFEATURES_APPID"],
              "secret"   => ENV["FLUIDFEATURES_SECRET"]
            })
          end

          $stderr.puts "fluidfeatures-rails is configured with app_id '#{config["app_id"]}'. Run 'rails g fluidfeatures:config' to update config"

          # create FF app store in global rails namespace
          ::FluidFeatures::Rails.ff_app = ::FluidFeatures.app(config)

          # wrap each request in fluidfeatures user transaction
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

    attr_accessor :ff_transaction

    # allow fluidfeature to be called from templates
    helper_method :ff?
    helper_method :fluidfeature
    helper_method :fluidgoal

    #
    # Here is how we know what your user_id is for the user
    # making the current request.
    # This must be overriden within the user application.
    # We recommend doing this in application_controller.rb
    #
    def fluidfeatures_initialize_user

      # call app defined method "fluidfeatures_current_user"
      user = nil
      begin
        user = fluidfeatures_current_user(verbose=true) || {}
      rescue NoMethodError
        raise FFeaturesException.new("Method fluidfeatures_current_user is not defined in your ApplicationController")
      end
      unless user.is_a? Hash
        raise FFeaturesException.new("fluidfeatures_current_user returned invalid user (Hash or nil expected) : #{user}")
      end

      # default to anonymous is no user id given
      user[:anonymous] = false unless user[:id]

      # if no user id given, then attempt to get the unique id of this visitor from the cookie
      user[:id] ||= cookies[:fluidfeatures_anonymous]

      url = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"

      transaction = ::FluidFeatures::Rails.ff_app.user_transaction(
        user[:id],
        url,
        user[:name],
        !!user[:anonymous],
        user[:uniques],
        user[:cohorts]
      )

      # Set/delete cookies for anonymous users
      if transaction.user.anonymous
        # update the cookie, with the unique id of this user
        cookies[:fluidfeatures_anonymous] = transaction.user.unique_id
      else
        # We are no longer an anoymous user. Delete the cookie
        if cookies.has_key? :fluidfeatures_anonymous
          cookies.delete(:fluidfeatures_anonymous)
        end
      end

      transaction
    end

    #
    # Initialize the FluidFeatures state for this request.
    #
    def fluidfeatures_request_before
      @ff_transaction = fluidfeatures_initialize_user
    end

    #
    # This is called by the developer's code to determine if the
    # feature, specified by "feature_name" is enabled for the
    # current user.
    # We call user_id to get the current user's unique id.
    #
    def fluidfeature(feature_name, version_name=nil, default_enabled=nil)

      # also support: fluidfeature(feature_name, default_enabled)
      if default_enabled == nil and (version_name.is_a? FalseClass or version_name.is_a? TrueClass)
        default_enabled = version_name
        version_name = nil
      end

      unless default_enabled.is_a? FalseClass or default_enabled.is_a? TrueClass
        default_enabled = fluidfeatures_default_enabled
      end

      unless ::FluidFeatures::Rails.enabled
        return default_enabled || false
      end

      ff_transaction.feature_enabled?(feature_name, version_name, default_enabled)
    end

    def fluidgoal(goal_name, goal_version_name=nil)
      unless ::FluidFeatures::Rails.enabled
        return default_enabled || false
      end
      ff_transaction.goal_hit(goal_name, goal_version_name)
    end

    #
    # Returns the features enabled for this request's user.
    #
    def fluidfeatures_retrieve_user_features
      ff_transaction.features
    end

    #
    # After the rails request is complete we will log which features we
    # encountered, including the default settings (eg. enabled) for each
    # feature.
    # This helps the FluidFeatures database prepopulate the feature set
    # without requiring the developer to do it manually.
    #
    def fluidfeatures_request_after
      ff_transaction.end_transaction
    end

    def fluidfeatures_default_enabled
      # By default unknown features are disabled.
      # Override and return "true" to have features enabled by default.
      false
    end

    def fluidfeatures_default_version_name
      "default"
    end

    alias :ff? :fluidfeature

  end
end

