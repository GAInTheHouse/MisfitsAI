# frozen_string_literal: true

module Navigation
  module_function

  def build(user)
    Progress.new(
      wardrobe_complete: wardrobe_complete?(user),
      calendar_complete: calendar_complete?(user),
      outfits_complete:  user.week_plans.joins(:outfit_recommendations).exists?
    )
  end

  def wardrobe_complete?(user)
    visible = user.garments.where(hidden_from_recommendations: false)
    return true if visible.exists?(category: "dress")

    visible.exists?(category: "top") && visible.exists?(category: "bottom")
  end

  def calendar_complete?(user)
    start = Date.current.beginning_of_week(:monday)
    user.week_plans
        .joins(:week_events)
        .where(week_start: start)
        .where.not(week_events: { event_type: "none" })
        .exists?
  end
end
