# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::Weather, type: :service do
  let(:location) { "New York" }
  let(:date) { Date.current }

  context "when WEATHER_API_KEY is missing" do
    it "returns default fallback forecast" do
      ClimateControl.modify(WEATHER_API_KEY: nil) do
        forecast = described_class.forecast_for(location: location, date: date)
        expect(forecast).to eq({
          temp_f: 72,
          condition: "Sunny",
          location: location,
          date: date
        })
      end
    end
  end

  context "when WEATHER_API_KEY is present" do
    let(:api_key) { "dummy_api_key" }

    it "parses successful weather API response" do
      ClimateControl.modify(WEATHER_API_KEY: api_key) do
        fake_response = instance_double(
          Faraday::Response,
          success?: true,
          body: {
            "main" => { "temp" => 68.4 },
            "weather" => [ { "main" => "Rain" } ]
          }.to_json
        )

        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(fake_response)

        forecast = described_class.forecast_for(location: location, date: date)
        expect(forecast[:temp_f]).to eq(68)
        expect(forecast[:condition]).to eq("Rain")
        expect(forecast[:location]).to eq(location)
      end
    end

    it "falls back gracefully on HTTP failure" do
      ClimateControl.modify(WEATHER_API_KEY: api_key) do
        fake_response = instance_double(Faraday::Response, success?: false)
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(fake_response)

        forecast = described_class.forecast_for(location: location, date: date)
        expect(forecast[:temp_f]).to eq(72)
        expect(forecast[:condition]).to eq("Sunny")
      end
    end

    it "falls back gracefully on network error" do
      ClimateControl.modify(WEATHER_API_KEY: api_key) do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)

        forecast = described_class.forecast_for(location: location, date: date)
        expect(forecast[:temp_f]).to eq(72)
        expect(forecast[:condition]).to eq("Sunny")
      end
    end
  end
end
