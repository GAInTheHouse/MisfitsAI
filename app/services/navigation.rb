# frozen_string_literal: true

module Navigation
  module_function

  def build(user)
    Progress.new(
      wardrobe_complete: wardrobe_complete?(user),
      calendar_complete: calendar_complete?(user),
      outfits_complete:  outfits_complete?(user)
    )
  end

  def wardrobe_complete?(user)
    visible = user.garments.where(hidden_from_recommendations: false)
    return true if visible.exists?(category: "dress")

    visible.exists?(category: "top") && visible.exists?(category: "bottom")
  end

  # Design doc §6.7: complete when Google is connected, OR the plan source is demo/google,
  # OR the user has manually edited at least one day this week.
  def calendar_complete?(user)
    start = Planner::Week.current_start(user)
    plan  = user.week_plans.find_by(week_start: start)
    return false unless plan

    return true if user.google_calendar_connected_at.present?
    return true if %w[demo google].include?(plan.source)

    plan.week_events.where.not(event_type: "none").exists?
  end

  # Design doc §7.2: complete when the current week's plan has generated recommendations.
  def outfits_complete?(user)
    start = Planner::Week.current_start(user)
    user.week_plans.where(week_start: start).joins(:outfit_recommendations).exists?
  end
end
