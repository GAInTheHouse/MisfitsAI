# frozen_string_literal: true

class WeekPlansController < ApplicationController
  before_action :authenticate_user!

  def show
    @week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    @events = @week_plan.week_events.order(:date)
    @recommendations = @week_plan.outfit_recommendations.order(:date).index_by(&:date)
    @event_options = ::Options.fetch(:event_types).map { |e| [ e[:key], e[:label] ] }
    @forecast = Planner::Weather.forecast_for(location: default_weather_location)
  end

  def demo
    plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    Planner::WeekPlanner.apply_demo_week!(plan)
    redirect_to week_plan_path, notice: "Demo week applied."
  end

  def generate
    unless current_user.garments.visible.outfit_ready?
      redirect_to week_plan_path, alert: "Add at least one top and one bottom (or a dress) first."
      return
    end

    plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    Planner::WeekPlanner.generate!(user: current_user, week_plan: plan)
    redirect_to outfits_path, notice: "Outfits generated for your week."
  end

  private

  def default_weather_location
    tz = current_user.time_zone.to_s
    iana = ActiveSupport::TimeZone::MAPPING[tz] || tz
    city = iana.split("/").last&.tr("_", " ") if iana.include?("/")
    city.presence || "New York"
  end
end
