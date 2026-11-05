# frozen_string_literal: true

module Analytics
  class Metrics
    CACHE_KEY = "analytics/metrics"
    CACHE_TTL = 10.minutes

    def self.call(period_days:)
      period_days = period_days.to_i.clamp(1, 366)
      new(period_days: period_days).call
    end

    def initialize(period_days:)
      @period_days = period_days
    end

    def call
      {
        signups:      User.count,
        active_users: ga4_data[:active_users],
        page_views:   ga4_data[:page_views],
        waitlist:     waitlist_count,
        ga4_configured: ga4_data[:configured],
        dummy_data:   false
      }
    end

    private

    def ga4_data
      @ga4_data ||= Rails.cache.fetch("#{CACHE_KEY}/ga4/#{@period_days}", expires_in: CACHE_TTL) do
        fetch_ga4
      end
    end

    def fetch_ga4
      property_id = ENV.fetch("GA4_PROPERTY_ID", "")
      credentials_json = ENV.fetch("GOOGLE_SERVICE_ACCOUNT_JSON", "")
      return { active_users: 0, page_views: 0, configured: false } if property_id.blank? || credentials_json.blank?

      require "google/analytics/data/v1beta"
      credentials = JSON.parse(credentials_json)
      client = Google::Analytics::Data::V1beta::AnalyticsData::Client.new do |config|
        config.credentials = credentials
      end

      response = client.run_report(
        property: "properties/#{property_id}",
        date_ranges: [{ start_date: "#{@period_days}daysAgo", end_date: "today" }],
        metrics: [{ name: "activeUsers" }, { name: "screenPageViews" }]
      )

      row = response.rows.first
      {
        active_users: row&.metric_values&.dig(0, :value).to_i,
        page_views:   row&.metric_values&.dig(1, :value).to_i,
        configured:   true
      }
    rescue StandardError => e
      Rails.logger.warn("[Analytics] GA4 fetch failed: #{e.class}")
      { active_users: 0, page_views: 0, configured: false }
    end

    def self.ga4_report
      new(period_days: 28).send(:fetch_ga4)
    end

    def waitlist_count
      self.class.formspree_count ||
        csv_count ||
        WaitlistEntry.count
    end

    def self.formspree_count
      form_id = ENV.fetch("FORMSPREE_FORM_ID", "")
      api_key = ENV.fetch("FORMSPREE_API_KEY", "")
      return nil if form_id.blank? || api_key.blank?

      uri = URI("https://formspree.io/api/0/forms/#{form_id}/submissions")
      req = Net::HTTP::Get.new(uri)
      req.basic_auth("", api_key)
      resp = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) { |h| h.request(req) }
      data = JSON.parse(resp.body)
      (data["total"] || data["submissions"]&.size).to_i
    rescue StandardError
      nil
    end

    def csv_count
      url = ENV.fetch("WAITLIST_SHEET_CSV_URL", "")
      return nil if url.blank?

      uri = URI(url)
      resp = Net::HTTP.get_response(uri)
      return nil unless resp.is_a?(Net::HTTPSuccess)

      rows = resp.body.force_encoding("UTF-8").split("\n").reject(&:blank?)
      skip_header = ActiveModel::Type::Boolean.new.cast(ENV.fetch("WAITLIST_CSV_SKIP_HEADER", "true"))
      count = rows.size
      skip_header ? [count - 1, 0].max : count
    rescue StandardError
      nil
    end
  end
end
