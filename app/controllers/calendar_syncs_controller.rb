# frozen_string_literal: true

class CalendarSyncsController < ApplicationController
  before_action :authenticate_user!

  def create
    unless Feature.enabled?(:calendar_sync)
      redirect_to week_plan_path, alert: "Calendar sync is temporarily unavailable."
      return
    end

    if current_user.google_refresh_token.blank?
      # 6.1: come back to the week plan and sync straight away. OmniAuth's request phase is POST-only
      # (omniauth-rails_csrf_protection), so a 307 makes the browser re-POST this form, token included.
      session[:return_to] = week_plan_path(sync: 1)
      redirect_to user_google_oauth2_omniauth_authorize_path, status: :temporary_redirect
      return
    end

    Planner::SyncCalendarJob.perform_later(current_user.id)
    redirect_to week_plan_path, notice: "Syncing your Google Calendar…"
  end
end
