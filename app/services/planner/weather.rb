# frozen_string_literal: true

require "faraday"
require "json"

module Planner
  class Weather
    DEFAULT_TEMP_F = 72
    DEFAULT_CONDITION = "Sunny"

    def self.forecast_for(location:, date: Date.current)
      new(location: location, date: date).fetch_forecast
    end

    def initialize(location:, date: Date.current)
      @location = location.to_s.strip
      @date = date
    end

    def fetch_forecast
      return default_forecast if api_key.blank? || @location.blank?

      response = connection.get("weather") do |req|
        req.params["q"] = @location
        req.params["appid"] = api_key
        req.params["units"] = "imperial"
      end

      return default_forecast unless response.success?

      data = JSON.parse(response.body)
      {
        temp_f: data.dig("main", "temp")&.round || DEFAULT_TEMP_F,
        condition: data.dig("weather", 0, "main") || DEFAULT_CONDITION,
        location: @location,
        date: @date
      }
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.warn("Planner::Weather API error: #{e.message}")
      default_forecast
    end

    private

    def api_key
      ENV["WEATHER_API_KEY"].presence || Rails.application.credentials.weather_api_key
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.openweathermap.org/data/2.5") do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 5
        faraday.options.open_timeout = 3
      end
    end

    def default_forecast
      {
        temp_f: DEFAULT_TEMP_F,
        condition: DEFAULT_CONDITION,
        location: @location,
        date: @date
      }
    end
  end
end
