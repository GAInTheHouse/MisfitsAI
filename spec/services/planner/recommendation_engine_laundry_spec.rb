# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::RecommendationEngine, "laundry filtering" do
  let(:context) do
    Struct.new(:gender, :measurements, :avoided_colors, :favorite_colors, :color_tone, keyword_init: true)
          .new(avoided_colors: [], favorite_colors: [])
  end
  let(:event) { Data.define(:date, :event_type).new(date: Date.current, event_type: "casual") }

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

  describe "shoes (issue #8)" do
    let(:user) { create(:user) }
    let(:tee) { create(:garment, :top, user:, formality: "casual") }
    let(:shorts) { create(:garment, :bottom, user:, formality: "casual") }

    def shoes_for(type, *shoes)
      events = [ Data.define(:date, :event_type).new(date: Date.current, event_type: type) ]
      described_class.call(garments: [ tee, shorts, *shoes ], events:, context: Profiles.for(user)).first.shoes
    end

    it "skips gym shoes that are in the laundry" do
      dirty = create(:garment, :shoes, user:, name: "Running Shoes", laundry_status: "in_laundry", times_recommended: 0)
      clean = create(:garment, :shoes, user:, name: "Trainers", laundry_status: "clean", times_recommended: 9)
      expect(shoes_for("gym", dirty, clean)).to eq(clean)
    end

    it "still picks shoes from the laundry when no clean pair exists" do
      dirty = create(:garment, :shoes, user:, name: "Running Shoes", laundry_status: "in_laundry")
      expect(shoes_for("gym", dirty)).to eq(dirty)
    end
  end
end
