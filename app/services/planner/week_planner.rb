# frozen_string_literal: true

module Planner
  # Orchestrates week plan creation, demo week setup, and outfit generation.
  # All methods are synchronous and fast: DB work only, no AI in the request.
  class WeekPlanner
    DEMO_WEEK = {
      0 => "work_meeting",
      1 => "gym",
      2 => "casual",
      3 => "work_meeting",
      4 => "date_night",
      5 => "casual",
      6 => "none"
    }.freeze

    def self.ensure_week!(user:)
      start = Date.current.beginning_of_week(:monday)
      user.week_plans.find_or_create_by!(week_start: start)
    end

    def self.apply_demo_week!(week_plan)
      start = week_plan.week_start
      DEMO_WEEK.each do |offset, event_type|
        date = start + offset
        week_plan.week_events.find_or_initialize_by(date: date).tap do |e|
          e.event_type = event_type
          e.save!
        end
      end
      week_plan.update!(source: "demo")
      week_plan
    end

    def self.generate!(user:, week_plan:)
      engine = RecommendationEngine.new(user: user)
      week_plan.outfit_recommendations.destroy_all

      start = week_plan.week_start
      (0..6).map do |offset|
        date = start + offset
        event = week_plan.week_events.find_by(date: date)
        event_type = event&.event_type || "none"
        garments = engine.call
        top, bottom, shoes = garments
        rec = week_plan.outfit_recommendations.create!(
          date: date,
          event_type: event_type,
          top: top,
          bottom: bottom,
          shoes: shoes,
          explanation_status: "pending",
          preview_status: "none"
        )
        Planner::ExplainOutfitJob.perform_later(rec.id)
        rec
      end
    end
  end
end
