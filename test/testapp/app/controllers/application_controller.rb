class ApplicationController < ActionController::Base

  # simple authentication. user passes their id
  def authenticate_user
    params[:user_id]
  end

  def current_user_id
    @current_user_id ||= authenticate_user
  end

  def fluidfeature_current_user(verbose=false)
    { :id => current_user_id }
  end

end
