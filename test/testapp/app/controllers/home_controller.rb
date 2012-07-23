class HomeController < ApplicationController
  def index
    enabled_features = []
    # apples is enabled by default
    if fluidfeature("apples", { :enabled => true })
      enabled_features << "apples"
    end
    %w{oranges lemons}.each do |feature_name|
      if fluidfeature(feature_name)
        enabled_features << feature_name
      end
    end
    # render a simple page that is a list of features enabled
    # separated by one space character
    render :inline => enabled_features.join(" ")
  end
end
