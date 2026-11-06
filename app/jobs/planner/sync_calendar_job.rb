# frozen_string_literal: true

module Planner
  class SyncCalendarJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless user

      Planner::CalendarSync.new(user: user).sync!
    end
  end
end
