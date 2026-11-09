# frozen_string_literal: true

module Planner
  # Orchestrates week plan creation, demo week setup, and outfit generation.
  class WeekPlanner
    DEMO_WEEK = {
      0 => "work_meeting",
      1 => "work_meeting",
      2 => "gym",
      3 => "work_meeting",
      4 => "date_night",
      5 => "casual",
      6 => "none"
    }.freeze

    def self.ensure_week!(user:)
      start = Week.current_start(user)
      plan = user.week_plans.find_or_initialize_by(week_start: start)
      if plan.new_record?
        plan.save!
        (0..6).each do |offset|
          plan.week_events.create!(date: start + offset, event_type: "none")
        end
      end
      plan
    end

    def self.apply_demo_week!(week_plan)
      start = week_plan.week_start
      DEMO_WEEK.each do |offset, event_type|
        date = start + offset
        week_plan.week_events.find_or_initialize_by(date: date).tap do |e|
          e.event_type = event_type
          e.original_summary = nil
          e.save!
        end
      end
      week_plan.update!(source: "demo")
      week_plan
    end

    def self.generate!(user:, week_plan:)
      suggestions = RecommendationEngine.call(
        garments: user.garments.with_attached_image.to_a,
        events: week_plan.week_events.order(:date).to_a,
        context: Profiles.for(user)
      )

      OutfitRecommendation.transaction do
        week_plan.outfit_recommendations.destroy_all
        recs = suggestions.map do |s|
          week_plan.outfit_recommendations.create!(
            date: s.date,
            event_type: s.event_type,
            top: s.top,
            bottom: s.bottom,
            dress: s.dress,
            outerwear: s.outerwear,
            shoes: s.shoes,
            explanation_status: "pending",
            preview_status: "none"
          )
        end

        ids = suggestions.flat_map { [ _1.top, _1.bottom, _1.dress, _1.outerwear, _1.shoes ] }.compact.map(&:id)
        ids.tally.each { |id, n| Garment.where(id:).update_all([ "times_recommended = times_recommended + ?", n ]) }

        week_plan.update!(generated_at: Time.current)
        recs.each { ExplainOutfitJob.perform_later(_1.id) }
        recs
      end
    end
  end
end
