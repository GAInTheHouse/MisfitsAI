# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::RecommendationEngine, "laundry filtering" do
  let(:context) do
    Struct.new(:gender, :measurements, :avoided_colors, :favorite_colors, :color_tone, keyword_init: true)
          .new(avoided_colors: [], favorite_colors: [])
  end
  let(:event) { Struct.new(:date, :event_type, keyword_init: true).new(date: Date.current, event_type: "casual") }

  it "prefers clean garments over garments currently in laundry" do
    dirty_top = Garment.new(id: "1", name: "Dirty Tee", category: "top", formality: "casual", laundry_status: "in_laundry", times_recommended: 0)
    clean_top = Garment.new(id: "2", name: "Clean Tee", category: "top", formality: "casual", laundry_status: "clean", times_recommended: 5)
    bottom = Garment.new(id: "3", name: "Jeans", category: "bottom", formality: "casual", laundry_status: "clean")

    suggestions = described_class.call(garments: [ dirty_top, clean_top, bottom ], events: [ event ], context:)
    expect(suggestions.first.top).to eq(clean_top)
  end

  it "falls back to an in-laundry garment if zero clean items exist in that category" do
    dirty_top = Garment.new(id: "1", name: "Only Tee", category: "top", formality: "casual", laundry_status: "in_laundry")
    bottom = Garment.new(id: "2", name: "Jeans", category: "bottom", formality: "casual", laundry_status: "clean")

    suggestions = described_class.call(garments: [ dirty_top, bottom ], events: [ event ], context:)
    expect(suggestions.first.top).to eq(dirty_top)
  end
end
