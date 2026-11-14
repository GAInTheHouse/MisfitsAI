# frozen_string_literal: true

class CalendarSyncsController < ApplicationController
  before_action :authenticate_user!

  def create
    unless Feature.enabled?(:calendar_sync)
      redirect_to week_plan_path, alert: "Calendar sync is temporarily unavailable."
      return
    end

    if current_user.google_refresh_token.blank?
      # The week plan's Connect button posts to OmniAuth directly (6.1); this only catches a stale page.
      redirect_to week_plan_path, alert: "Connect Google Calendar first."
      return
    end

    Planner::SyncCalendarJob.perform_later(current_user.id)
    redirect_to week_plan_path, notice: "Syncing your Google Calendar…"
  end
end
