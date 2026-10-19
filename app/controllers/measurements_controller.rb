# frozen_string_literal: true

class MeasurementsController < ApplicationController
  include ComingSoon
  skip_before_action :require_onboarding!
  def update; head :not_implemented; end
end
