# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::Weather, type: :service do
  it "returns a fallback forecast hash when API key is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("WEATHER_API_KEY").and_return(nil)

    forecast = described_class.forecast_for(location: "New York")
    expect(forecast).to include(temp_f: 72, condition: "Sunny", location: "New York", date: Date.current)
  end

  it "parses temperature and condition from OpenWeatherMap responses" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/data/2.5/weather") do
        [ 200, { "Content-Type" => "application/json" }, '{"main":{"temp":48.6},"weather":[{"main":"Clouds"}]}' ]
      end
    end
    conn = Faraday.new(url: "https://api.openweathermap.org/data/2.5") { |f| f.adapter :test, stubs }

    service = described_class.new(location: "New York", date: Date.new(2026, 11, 13))
    allow(service).to receive(:api_key).and_return("test-key")
    allow(service).to receive(:connection).and_return(conn)

    expect(service.fetch_forecast).to eq(
      temp_f: 49,
      condition: "Clouds",
      location: "New York",
      date: Date.new(2026, 11, 13)
    )
  end

  describe ".location_for" do
    it "uses the city from the user's time zone, in a form OpenWeatherMap accepts" do
      expect(described_class.location_for(build(:user, time_zone: "America/New_York"))).to eq("New York")
      expect(described_class.location_for(build(:user, time_zone: "Pacific/Auckland"))).to eq("Auckland")
      expect(described_class.location_for(build(:user, time_zone: "Eastern Time (US & Canada)"))).to eq("New York")
    end

    it "falls back to New York when the zone has no city" do
      expect(described_class.location_for(build(:user, time_zone: "UTC"))).to eq("New York")
      expect(described_class.location_for(nil)).to eq("New York")
    end
  end
end
