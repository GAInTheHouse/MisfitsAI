# frozen_string_literal: true

class OutfitsController < ApplicationController
  before_action :authenticate_user!

  def index
    week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    @outfits = week_plan.outfit_recommendations
                        .includes(:top, :bottom, :dress, :outerwear, :shoes)
                        .order(:date)
  end

  def show
    @outfit = OutfitRecommendation.joins(:week_plan)
                                  .where(week_plans: { user: current_user })
                                  .find(params[:id])
  end
end
