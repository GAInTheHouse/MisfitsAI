# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::RecommendationEngine, "selection edge cases" do
  let(:user) { create(:user) }
  let(:context) { Profiles.for(user) }

  def suggest(garments, event_type:, recently_worn_ids: Set.new, context: nil, **kwargs)
    event = Data.define(:date, :event_type).new(date: Date.current, event_type:)
    described_class.call(
      garments:, events: [ event ], context: context || self.context, recently_worn_ids:, **kwargs
    ).first
  end

  it "prefers a dress on date night when one is available" do
    dress = create(:garment, user:, category: "dress", formality: "smart_casual", name: "Midi Dress")
    top = create(:garment, :top, user:, formality: "smart_casual", name: "Blouse")
    bottom = create(:garment, :bottom, user:, formality: "smart_casual", name: "Skirt")
    shoes = create(:garment, :shoes, user:, formality: "smart_casual")

    outfit = suggest([ dress, top, bottom, shoes ], event_type: "date_night")

    expect(outfit.dress).to eq(dress)
    expect(outfit.top).to be_nil
    expect(outfit.bottom).to be_nil
  end

  it "treats a none event like casual" do
    tee = create(:garment, :top, user:, formality: "casual", name: "Tee", times_recommended: 0)
    jeans = create(:garment, :bottom, user:, formality: "casual", name: "Jeans")
    shoes = create(:garment, :shoes, user:, formality: "casual")
    garments = [ tee, jeans, shoes ]

    none_outfit = suggest(garments, event_type: "none")
    casual_outfit = suggest(garments, event_type: "casual")

    expect(none_outfit.top).to eq(casual_outfit.top)
    expect(none_outfit.bottom).to eq(casual_outfit.bottom)
  end

  it "deprioritizes recently worn pieces when scores tie" do
    worn = create(:garment, :top, user:, formality: "casual", times_recommended: 2, name: "Worn Tee")
    fresh = create(:garment, :top, user:, formality: "casual", times_recommended: 2, name: "Fresh Tee")
    jeans = create(:garment, :bottom, user:, formality: "casual")
    shoes = create(:garment, :shoes, user:, formality: "casual")

    outfit = suggest([ worn, fresh, jeans, shoes ], event_type: "casual", recently_worn_ids: Set[worn.id])

    expect(outfit.top).to eq(fresh)
  end

  it "avoids colors the user marked as disliked" do
    user.profile.update!(avoided_colors: %w[red])
    red = create(:garment, :top, user:, color_primary: "red", formality: "casual", times_recommended: 0)
    blue = create(:garment, :top, user:, color_primary: "blue", formality: "casual", times_recommended: 0)
    jeans = create(:garment, :bottom, user:, formality: "casual")
    shoes = create(:garment, :shoes, user:, formality: "casual")

    outfit = suggest([ red, blue, jeans, shoes ], event_type: "casual", context: Profiles.for(user.reload))

    expect(outfit.top).to eq(blue)
  end

  it "skips hoodies for work meetings" do
    hoodie = create(:garment, :top, user:, sub_category: "hoodie", formality: "casual", name: "Gray Hoodie")
    oxford = create(:garment, :top, user:, sub_category: "shirt", formality: "business", name: "Oxford Shirt")
    pants = create(:garment, :bottom, user:, formality: "business", sub_category: "dress_pants")
    shoes = create(:garment, :shoes, user:, formality: "business", name: "Loafers")

    outfit = suggest([ hoodie, oxford, pants, shoes ], event_type: "work_meeting")

    expect(outfit.top).to eq(oxford)
  end

  it "falls back to a dress when no top/bottom pair exists" do
    dress = create(:garment, user:, category: "dress", formality: "casual", name: "Sundress")
    shoes = create(:garment, :shoes, user:, formality: "casual")

    outfit = suggest([ dress, shoes ], event_type: "casual")

    expect(outfit.dress).to eq(dress)
    expect(outfit.top).to be_nil
    expect(outfit.bottom).to be_nil
  end
end
