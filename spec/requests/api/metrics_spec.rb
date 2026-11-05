# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/metrics", type: :request do
  let(:valid_key) { "test-analytics-key-123" }

  around do |ex|
    ClimateControl.modify(
      ANALYTICS_INTERNAL_API_KEY: valid_key,
      ANALYTICS_USE_DUMMY_METRICS: "false",
      GA4_PROPERTY_ID: "",
      FORMSPREE_FORM_ID: "",
      WAITLIST_SHEET_CSV_URL: ""
    ) { ex.run }
  end

  context "without the API key" do
    it "returns 401" do
      get "/api/metrics"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with the wrong API key" do
    it "returns 401" do
      get "/api/metrics", headers: { "X-Analytics-Key" => "wrong" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with the correct API key" do
    let(:headers) { { "X-Analytics-Key" => valid_key } }

    it "returns the expected shape" do
      get "/api/metrics", headers: headers
      expect(response).to have_http_status(:ok)
      expect(parsed_body.keys).to include("signups", "active_users", "page_views", "waitlist")
    end

    it "clamps period_days to 1..366" do
      get "/api/metrics?period_days=9999", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "includes signups count" do
      create(:user)
      get "/api/metrics", headers: headers
      expect(parsed_body["signups"]).to eq(User.count)
    end
  end

  context "in dummy mode" do
    around do |ex|
      ClimateControl.modify(
        ANALYTICS_USE_DUMMY_METRICS: "true",
        ANALYTICS_INTERNAL_API_KEY: valid_key
      ) { ex.run }
    end

    it "returns dummy data without calling GA4" do
      get "/api/metrics", headers: { "X-Analytics-Key" => valid_key }
      expect(response).to have_http_status(:ok)
      expect(parsed_body["signups"]).to eq(2)
      expect(parsed_body["dummy_data"]).to be true
    end
  end

  context "when key auth is skipped" do
    around do |ex|
      ClimateControl.modify(
        ANALYTICS_SKIP_KEY_AUTH: "true",
        ANALYTICS_INTERNAL_API_KEY: valid_key
      ) { ex.run }
    end

    it "allows unauthenticated access" do
      get "/api/metrics"
      expect(response).to have_http_status(:ok)
    end
  end

  def parsed_body
    JSON.parse(response.body)
  end
end
