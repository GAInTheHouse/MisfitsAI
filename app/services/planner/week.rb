# frozen_string_literal: true

module Planner
  module Week
    module_function

    def current_start(user)
      Time.current.in_time_zone(user.time_zone).to_date.beginning_of_week(:monday)
    end
  end
end
