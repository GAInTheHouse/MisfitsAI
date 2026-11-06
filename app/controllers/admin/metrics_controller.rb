# frozen_string_literal: true

module Admin
  class MetricsController < BaseController
    def show
      period_days = params.fetch(:period_days, 28).to_i.clamp(1, 366)

      if ActiveModel::Type::Boolean.new.cast(ENV.fetch("ANALYTICS_USE_DUMMY_METRICS", "false"))
        return render json: {
          signups: 2, active_users: 3, waitlist: 5, page_views: 5,
          period_days: period_days, as_of: Time.current.iso8601,
          ga4_configured: false, dummy_data: true
        }
      end

      data = Analytics::Metrics.call(period_days: period_days)
      render json: data.merge(period_days: period_days, as_of: Time.current.iso8601)
    end
  end
end
