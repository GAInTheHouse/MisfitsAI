# frozen_string_literal: true

class TimeZonesController < ApplicationController
  skip_before_action :require_onboarding!

  def update
    tz = params[:time_zone].to_s
    if ActiveSupport::TimeZone[tz]
      current_user.update!(time_zone: tz)
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
