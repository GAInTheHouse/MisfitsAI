# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weather API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :onboarded, time_zone: "America/New_York") }
  let(:forecast) { { temp_f: 55, condition: "Clouds", location: "New York" } }

  before { sign_in user }

  it "returns a forecast for the default city from the user's time zone" do
    allow(Planner::Weather).to receive(:forecast_for).with(location: "New York", date: Date.current).and_return(forecast)

    get "/weather"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("temp_f" => 55, "condition" => "Clouds")
  end

  it "honors an explicit location" do
    allow(Planner::Weather).to receive(:forecast_for).with(location: "Boston", date: Date.current).and_return(forecast.merge(location: "Boston"))

    get "/weather", params: { location: "Boston" }

    expect(Planner::Weather).to have_received(:forecast_for).with(location: "Boston", date: Date.current)
  end

  it "parses a valid date and falls back to today when the date is invalid" do
    travel_to Date.new(2026, 3, 10) do
      allow(Planner::Weather).to receive(:forecast_for).and_return(forecast)

      get "/weather", params: { date: "2026-03-12" }
      expect(Planner::Weather).to have_received(:forecast_for).with(hash_including(date: Date.new(2026, 3, 12)))

      get "/weather", params: { date: "not-a-date" }
      expect(Planner::Weather).to have_received(:forecast_for).with(hash_including(date: Date.current))
    end
  end
end
