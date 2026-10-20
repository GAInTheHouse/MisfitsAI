# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :require_onboarding!
    before_action :verify_analytics_key!

    private

    def verify_analytics_key!
      key = request.headers["X-Analytics-Key"].to_s
      expected = ENV.fetch("ANALYTICS_INTERNAL_API_KEY", "")
      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(key, expected)

      head :unauthorized
    end
  end
end
