# frozen_string_literal: true

# Issue #8: one day of the current week as a timeline of outfits (one per time block).
class TodayOutfitsController < ApplicationController
  before_action :authenticate_user!

  def show
    @week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    week = @week_plan.week_start..(@week_plan.week_start + 6)
    today = Time.current.in_time_zone(current_user.time_zone).to_date
    @date = selected_date(week) || (week.cover?(today) ? today : week.first)
    @previous_date = @date - 1 if week.cover?(@date - 1)
    @next_date = @date + 1 if week.cover?(@date + 1)
    @day_event = @week_plan.week_events.find_by(date: @date)
    @outfits = @week_plan.outfit_recommendations.where(date: @date).in_day_order
                         .includes(top: { image_attachment: :blob }, bottom: { image_attachment: :blob },
                                   dress: { image_attachment: :blob }, outerwear: { image_attachment: :blob },
                                   shoes: { image_attachment: :blob })
  end

  private

  def selected_date(week)
    date = Date.iso8601(params[:date].to_s)
    date if week.cover?(date)
  rescue Date::Error
    nil
  end
end
