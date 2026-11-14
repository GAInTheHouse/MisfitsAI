# frozen_string_literal: true

class OutfitsController < ApplicationController
  before_action :authenticate_user!

  def index
    @week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    recs = @week_plan.outfit_recommendations
                     .includes(:top, :bottom, :dress, :outerwear, :shoes)
                     .in_day_order
    @recs_by_day     = recs.group_by { |r| (r.date - @week_plan.week_start).to_i }
    today_offset     = (Date.current - @week_plan.week_start).to_i.clamp(0, 6)
    @selected_day    = params[:day]&.to_i&.clamp(0, 6) || today_offset
    @avatar_ready    = current_user.profile.avatar_status == "ready" &&
                       current_user.profile.avatar.attached?
    @preview_enabled = Feature.enabled?(:outfit_preview)
    @outfit_ready    = current_user.garments.visible.outfit_ready?
  end

  def show
    @outfit = OutfitRecommendation.joins(:week_plan)
                                  .where(week_plans: { user: current_user })
                                  .includes(:top, :bottom, :dress, :outerwear, :shoes)
                                  .find(params[:id])
    @avatar_ready    = current_user.profile.avatar_status == "ready" &&
                       current_user.profile.avatar.attached?
    @preview_enabled = Feature.enabled?(:outfit_preview)
  end

  def regenerate
    week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    unless current_user.garments.visible.outfit_ready?
      return redirect_to outfits_path,
                         alert: "Add at least one top and one bottom (or a dress) first."
    end
    Planner::WeekPlanner.generate!(user: current_user, week_plan: week_plan)
    redirect_to outfits_path, notice: "Regenerating this week's outfits…"
  end
end
