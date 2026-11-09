# frozen_string_literal: true

class CalendarSyncsController < ApplicationController
  before_action :authenticate_user!

  def create
    unless Feature.enabled?(:calendar_sync)
      redirect_to week_plan_path, alert: "Calendar sync is temporarily unavailable."
      return
    end

    if current_user.google_refresh_token.blank?
      session[:return_to] = week_plan_path
      redirect_to user_google_oauth2_omniauth_authorize_path, allow_other_host: true
      return
    end

    Planner::SyncCalendarJob.perform_later(current_user.id)
    redirect_to week_plan_path, notice: "Calendar sync initiated."
  end
end
