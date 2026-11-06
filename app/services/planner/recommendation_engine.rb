# frozen_string_literal: true

module Planner
  class RecommendationEngine
    def initialize(user:, date: Date.current)
      @user = user
      @date = date
    end

    def call
      garments = @user.garments.where(hidden_from_recommendations: false)
      return nil if garments.empty?

      tops = garments.select { |g| g.category == "top" }
      bottoms = garments.select { |g| g.category == "bottom" }
      shoes = garments.select { |g| g.category == "shoes" }

      top = tops.sample || garments.sample
      bottom = bottoms.sample
      shoe = shoes.sample

      [ top, bottom, shoe ].compact
    end
  end
end
