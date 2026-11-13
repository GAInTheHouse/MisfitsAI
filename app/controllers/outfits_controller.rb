# frozen_string_literal: true

class OutfitsController < ApplicationController
  before_action :authenticate_user!

  def index
    @outfits = OutfitRecommendation.joins(:week_plan)
                                   .where(week_plans: { user: current_user })
                                   .order(date: :desc)
    @forecast = Planner::Weather.forecast_for(location: default_weather_location)
  end

  def show
    @outfit = OutfitRecommendation.joins(:week_plan)
                                  .where(week_plans: { user: current_user })
                                  .find(params[:id])
  end

  private

  def default_weather_location
    tz = current_user.time_zone.to_s
    iana = ActiveSupport::TimeZone::MAPPING[tz] || tz
    city = iana.split("/").last&.tr("_", " ") if iana.include?("/")
    city.presence || "New York"
  end
end
