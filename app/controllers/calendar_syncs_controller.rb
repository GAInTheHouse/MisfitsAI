# frozen_string_literal: true

class CalendarSyncsController < ApplicationController
  before_action :authenticate_user!

  def create
    Planner::SyncCalendarJob.perform_later(current_user.id)
    redirect_to week_plan_path, notice: "Calendar sync initiated."
  end
end
