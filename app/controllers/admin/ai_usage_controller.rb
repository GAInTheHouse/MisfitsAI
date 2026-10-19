# frozen_string_literal: true

module Admin
  class AiUsageController < BaseController
    def show
      today = Time.current.utc.beginning_of_day
      rows = AiCall.where("created_at >= ?", today).group(:kind).select(
        "kind, COUNT(*) AS call_count, SUM(est_cost_cents) AS total_cents, AVG(latency_ms) AS avg_latency"
      )
      render json: {
        date: today.to_date.iso8601,
        by_kind: rows.map do |r|
          { kind: r.kind, calls: r.call_count, est_cost_cents: r.total_cents.to_f, avg_latency_ms: r.avg_latency.to_f }
        end
      }
    end
  end
end
