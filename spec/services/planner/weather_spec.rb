# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::Weather, type: :service do
  it "returns a forecast hash for a given location" do
    forecast = described_class.forecast_for(location: "New York")
    expect(forecast).to include(:temp_f, :condition, :location, :date)
  end
end
