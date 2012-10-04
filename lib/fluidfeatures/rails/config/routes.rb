
require 'fluidfeatures/rails/app/controllers/fluidfeatures_controller'

Rails.application.routes.draw do
  match "/fluidfeature/:feature_name"         => "fluid_feature_ajax#index"
  match "/fluidgoal/:goal_name"               => "fluid_goal_ajax#index"
  match "/fluidgoal/:goal_name/:goal_version" => "fluid_goal_ajax#index"
end
