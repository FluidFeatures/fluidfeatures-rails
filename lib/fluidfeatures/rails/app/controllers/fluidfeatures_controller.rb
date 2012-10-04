
class FluidFeatureAjaxController < ApplicationController
  
  def index
    render :json => {
      :enabled => fluidfeature(params[:feature_name])
    }, :status => 200
  end
end

#
# This is a controller you can use to sends stats from your browser
#

class FluidGoalAjaxController < ApplicationController
  def index
    fluidgoal(params[:goal_name], { :version => params[:goal_version] })
    render :json => {}, :status => 200
  end
end
