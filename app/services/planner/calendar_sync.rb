# frozen_string_literal: true

module Planner
  class CalendarSync
    def initialize(user:)
      @user = user
    end

    def sync!
      true
    end
  end
end
