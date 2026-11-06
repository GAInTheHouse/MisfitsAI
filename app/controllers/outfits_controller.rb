# frozen_string_literal: true

class OutfitsController < ApplicationController
  before_action :authenticate_user!

  def index
    @outfits = OutfitRecommendation.joins(:week_plan)
                                   .where(week_plans: { user: current_user })
                                   .order(date: :desc)
  end

  def show
    @outfit = OutfitRecommendation.joins(:week_plan)
                                  .where(week_plans: { user: current_user })
                                  .find(params[:id])
  end
end
