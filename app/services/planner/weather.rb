# frozen_string_literal: true

module Planner
  class Weather
    def self.forecast_for(location:, date: Date.current)
      {
        temp_f: 72,
        condition: "Sunny",
        location: location,
        date: date
      }
    end
  end
end
