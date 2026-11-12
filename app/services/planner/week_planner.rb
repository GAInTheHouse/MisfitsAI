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
          e.calendar_events.delete_all
        end
      end
      week_plan.update!(source: "demo")
      week_plan
    end

    RECENTLY_WORN_WINDOW = 7.days
    SLOTS = %i[top bottom dress outerwear shoes].freeze

    # Issue #8: one recommendation per time block (Planner::DaySegmenter), segment 0 for a single-block day.
    # Days with an outfit the user confirmed wearing are history: they are kept, not regenerated.
    def self.generate!(user:, week_plan:)
      garments = user.garments.with_attached_image.to_a
      worn_dates = week_plan.outfit_recommendations.where.not(worn_at: nil).distinct.pluck(:date).to_set
      days = week_plan.week_events.includes(:calendar_events).order(:date).reject { worn_dates.include?(_1.date) }
      ready = smart_casual_ready?(garments)
      segments = days.flat_map do |day|
        DaySegmenter.call(week_event: day, calendar_events: day.calendar_events.to_a, smart_casual_ready: ready,
                          time_zone: user.time_zone)
      end

      suggestions = RecommendationEngine.call(
        garments:, events: segments, context: Profiles.for(user), recently_worn_ids: recently_worn_ids(user)
      )

      OutfitRecommendation.transaction do
        week_plan.outfit_recommendations.where.not(date: worn_dates.to_a).destroy_all
        recs = suggestions.zip(segments).map do |s, segment|
          week_plan.outfit_recommendations.create!(
            date: s.date,
            event_type: s.event_type,
            top: s.top,
            bottom: s.bottom,
            dress: s.dress,
            outerwear: s.outerwear,
            shoes: s.shoes,
            segment_index: segment.index,
            starts_at: segment.starts_at,
            ends_at: segment.ends_at,
            segment_label: segment.label,
            change_reason: segment.change_reason,
            explanation_status: "pending",
            preview_status: "none"
          )
        end

        ids = suggestions.flat_map { |s| SLOTS.map { s.public_send(_1) } }.compact.map(&:id)
        ids.tally.each { |id, n| Garment.where(id:).update_all([ "times_recommended = times_recommended + ?", n ]) }

        week_plan.update!(generated_at: Time.current)
        recs.each { ExplainOutfitJob.perform_later(_1.id) }
        recs
      end
    end

    # A work meeting and a date night can share one outfit only if the wardrobe has smart-casual pieces for it.
    def self.smart_casual_ready?(garments)
      smart = garments.reject(&:hidden_from_recommendations).select { _1.formality == "smart_casual" }
      smart.any? { _1.category == "dress" } ||
        (smart.any? { _1.category == "top" } && smart.any? { _1.category == "bottom" })
    end

    def self.recently_worn_ids(user)
      OutfitRecommendation.joins(:week_plan).where(week_plans: { user_id: user.id })
                          .where(worn_at: RECENTLY_WORN_WINDOW.ago..)
                          .pluck(*SLOTS.map { :"#{_1}_id" }).flatten.compact.to_set
    end
  end
end
