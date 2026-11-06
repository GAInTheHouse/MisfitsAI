# frozen_string_literal: true

class WeekPlansController < ApplicationController
  before_action :authenticate_user!

  def show
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_week
    @recommendations = Planner::RecommendationEngine.new(user: current_user, date: @start_date).call
  end

  def create
    engine = Planner::RecommendationEngine.new(user: current_user)
    engine.call
    redirect_to week_plan_path, notice: "Week plan generated."
  end
end
