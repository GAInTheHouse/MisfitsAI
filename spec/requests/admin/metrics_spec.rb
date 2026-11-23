# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /admin/metrics", type: :request do
  let(:valid_key) { "test-analytics-key-123" }
  let(:headers) { { "X-Analytics-Key" => valid_key } }

  around do |ex|
    ClimateControl.modify(
      ANALYTICS_INTERNAL_API_KEY: valid_key,
      ANALYTICS_USE_DUMMY_METRICS: "false",
      GA4_PROPERTY_ID: "",
      GOOGLE_SERVICE_ACCOUNT_JSON: ""
    ) { ex.run }
  end

  it "returns zeros with ga4_configured false when GA4 is not configured" do
    get "/admin/metrics", headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["active_users"]).to eq(0)
    expect(body["ga4_configured"]).to be false
  end
end
