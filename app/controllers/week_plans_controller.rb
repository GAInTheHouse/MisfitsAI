# frozen_string_literal: true

class WeekPlansController < ApplicationController
  before_action :authenticate_user!

  def show
    # Back from Google's consent screen (CalendarSyncsController sets return_to with sync=1): sync once,
    # then drop the param so a reload does not queue another sync.
    if params[:sync].present?
      if current_user.google_refresh_token.present? && Feature.enabled?(:calendar_sync)
        Planner::SyncCalendarJob.perform_later(current_user.id)
        flash[:notice] = "Google Calendar connected. Syncing your week…"
      end
      redirect_to week_plan_path
      return
    end

    load_week_plan
  end

  def demo
    plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    Planner::WeekPlanner.apply_demo_week!(plan)
    redirect_to week_plan_path, notice: "Demo week applied."
  end

  def generate
    unless current_user.garments.visible.outfit_ready?
      # Rendered rather than redirected: flash.now keeps the HTML-safe link, a redirect's flash would not.
      flash.now[:alert] = helpers.safe_join(
        [ "Add at least one top and one bottom (or a dress) first. ",
          helpers.link_to("Go to your wardrobe", wardrobe_path, class: "underline") ]
      )
      load_week_plan
      render :show, status: :unprocessable_entity
      return
    end

    plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    Planner::WeekPlanner.generate!(user: current_user, week_plan: plan)
    redirect_to outfits_path, notice: "Outfits generated for your week."
  end

  private

  def load_week_plan
    @week_plan = Planner::WeekPlanner.ensure_week!(user: current_user)
    @events = @week_plan.week_events.order(:date)
    @recommendations = @week_plan.outfit_recommendations.order(:date).index_by(&:date)
    @event_options = ::Options.fetch(:event_types).map { |e| [ e[:key], e[:label] ] }
    # Planner::CalendarSync clears the tokens when Google rejects them; keep asking until the user reconnects.
    @google_reconnect_needed = current_user.google_refresh_token.blank? &&
                               (current_user.google_calendar_connected_at.present? || current_user.uid.present?)
  end
end
