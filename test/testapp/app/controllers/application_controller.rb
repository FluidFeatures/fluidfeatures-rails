class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_user

  # simple authentication. user passes their id
  def authenticate_user
    user_id = params[:user_id]
    unless user_id
      raise "user_id not given"
    end
    
    # inform fluidfeatures gem of the user id
    fluidfeatures_set_user_id(user_id)
  end

end
