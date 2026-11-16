# frozen_string_literal: true

class WeatherController < ApplicationController
  before_action :authenticate_user!

  def show
    location = params[:location].to_s.strip.presence || default_location
    render json: Planner::Weather.forecast_for(location: location, date: parsed_date)
  end

  private

  def default_location
    tz = current_user.time_zone.to_s
    iana = ActiveSupport::TimeZone::MAPPING[tz] || tz
    city = iana.split("/").last&.tr("_", " ") if iana.include?("/")
    city.presence || "New York"
  end

  def parsed_date
    Date.iso8601(params[:date].to_s)
  rescue Date::Error
    Date.current
  end
end
