# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::RecommendationEngine, type: :service do
  let(:user) { create(:user) }
  let(:start) { Date.new(2026, 10, 19) } # Monday
  let(:context) { Profiles.for(user) }

  def events_for(types)
    types.each_with_index.map do |etype, i|
      build(:week_event, date: start + i, event_type: etype)
    end
  end

  def call_engine(garments, types)
    described_class.call(garments:, events: events_for(types), context:)
  end

  describe "empty wardrobe" do
    it "returns nil slots for each day" do
      result = call_engine([], %w[casual])
      expect(result.size).to eq(1)
      expect(result.first.top).to be_nil
      expect(result.first.bottom).to be_nil
    end
  end

  describe "formality chains" do
    it "picks business pieces for work_meeting" do
      oxford = create(:garment, :top, user:, name: "Oxford", formality: "business", sub_category: "shirt")
      hoodie = create(:garment, :top, user:, name: "Hoodie", formality: "casual", sub_category: "hoodie")
      pants  = create(:garment, :bottom, user:, name: "Dress Pants", formality: "business", sub_category: "dress_pants")
      day = call_engine([ oxford, hoodie, pants ], %w[work_meeting]).first
      expect(day.top).to eq(oxford)
      expect(day.bottom).to eq(pants)
      expect(day.top).not_to eq(hoodie)
    end

    it "excludes hoodies for work via sub_category blocklist" do
      hoodie = create(:garment, :top, user:, name: "Gray Hoodie", formality: "business", sub_category: "hoodie")
      pants  = create(:garment, :bottom, user:, formality: "business")
      day = call_engine([ hoodie, pants ], %w[work_meeting]).first
      expect(day.top).to be_nil
    end
  end

  describe "gym filter" do
    it "rejects dress shoes and blazer-like items" do
      tee   = create(:garment, :top, user:, formality: "casual", sub_category: "t_shirt", name: "Gym Tee")
      legs  = create(:garment, :bottom, user:, formality: "casual", sub_category: "leggings", name: "Leggings")
      heels = create(:garment, :shoes, user:, formality: "casual", name: "Black Heels")
      sneaker = create(:garment, :shoes, user:, formality: "casual", name: "Running Shoes")
      day = call_engine([ tee, legs, heels, sneaker ], %w[gym]).first
      expect(day.shoes).to eq(sneaker)
    end
  end

  describe "color preferences" do
    before do
      user.profile.update!(favorite_colors: %w[navy], avoided_colors: %w[orange], color_tone: "cool")
    end

    it "penalizes avoided colors when ties are equal" do
      navy = create(:garment, :top, user:, formality: "casual", color_primary: "navy", times_recommended: 0)
      orange = create(:garment, :top, user:, formality: "casual", color_primary: "orange", times_recommended: 0)
      bottom = create(:garment, :bottom, user:, formality: "casual")
      day = call_engine([ navy, orange, bottom ], %w[casual]).first
      expect(day.top).to eq(navy)
    end
  end

  describe "size beats color" do
    before do
      user.profile.update!(avoided_colors: %w[orange])
      create(:body_measurement, user:, chest_cm: 88)
    end

    it "prefers size-matched item even when color is avoided" do
      m_top = create(:garment, :top, user:, formality: "casual", color_primary: "orange", size: "M")
      l_top = create(:garment, :top, user:, formality: "casual", color_primary: "blue", size: "XL")
      bottom = create(:garment, :bottom, user:, formality: "casual")
      day = call_engine([ m_top, l_top, bottom ], %w[casual]).first
      expect(day.top).to eq(m_top)
    end
  end

  describe "rotation" do
    it "prefers lower times_recommended" do
      a = create(:garment, :top, user:, formality: "casual", times_recommended: 0)
      b = create(:garment, :top, user:, formality: "casual", times_recommended: 5)
      bottom = create(:garment, :bottom, user:, formality: "casual")
      day = call_engine([ a, b, bottom ], %w[casual]).first
      expect(day.top).to eq(a)
    end

    it "avoids reusing the same top across days when possible" do
      t1 = create(:garment, :top, user:, formality: "casual", times_recommended: 0)
      t2 = create(:garment, :top, user:, formality: "casual", times_recommended: 0)
      b1 = create(:garment, :bottom, user:, formality: "casual")
      b2 = create(:garment, :bottom, user:, formality: "casual")
      days = call_engine([ t1, t2, b1, b2 ], %w[casual casual])
      tops = days.map(&:top)
      expect(tops.uniq.size).to eq(2)
    end
  end

  describe "date night dress-first" do
    it "prefers a dress without reusing across back-to-back date nights" do
      d1 = create(:garment, :dress, user:, formality: "smart_casual", name: "Red Dress")
      d2 = create(:garment, :dress, user:, formality: "smart_casual", name: "Blue Dress")
      days = call_engine([ d1, d2 ], %w[date_night date_night])
      expect(days.map(&:dress)).to match_array([ d1, d2 ])
    end
  end

  describe "dress fallback" do
    it "uses a dress when separates are missing" do
      dress = create(:garment, :dress, user:, formality: "casual")
      day = call_engine([ dress ], %w[casual]).first
      expect(day.dress).to eq(dress)
      expect(day.top).to be_nil
    end
  end

  describe "gender filter" do
    it "excludes women's garments for male profile" do
      user.profile.update!(gender: "male")
      women_top = create(:garment, :top, user:, gender: "women", formality: "casual")
      men_top = create(:garment, :top, user:, gender: "men", formality: "casual")
      bottom = create(:garment, :bottom, user:, formality: "casual")
      ctx = Profiles.for(user.reload)
      day = described_class.call(
        garments: [ women_top, men_top, bottom ],
        events: events_for(%w[casual]),
        context: ctx
      ).first
      expect(day.top).to eq(men_top)
    end
  end

  describe "none maps to casual selection" do
    it "still builds a casual outfit for none days" do
      top = create(:garment, :top, user:, formality: "casual")
      bottom = create(:garment, :bottom, user:, formality: "casual")
      day = call_engine([ top, bottom ], %w[none]).first
      expect(day.event_type).to eq("none")
      expect(day.top).to eq(top)
    end
  end

  describe "outerwear" do
    it "adds outerwear on work_meeting when top is not structured" do
      top = create(:garment, :top, user:, formality: "business", sub_category: "shirt", name: "Oxford")
      coat = create(:garment, :outerwear, user:, formality: "smart_casual", name: "Trench")
      pants = create(:garment, :bottom, user:, formality: "business")
      day = call_engine([ top, pants, coat ], %w[work_meeting]).first
      expect(day.outerwear).to eq(coat)
    end

    it "skips outerwear when top is a blazer" do
      blazer = create(:garment, :top, user:, formality: "business", sub_category: "blazer", name: "Black Blazer")
      coat = create(:garment, :outerwear, user:, name: "Puffer")
      pants = create(:garment, :bottom, user:, formality: "business")
      day = call_engine([ blazer, pants, coat ], %w[work_meeting]).first
      expect(day.outerwear).to be_nil
    end
  end

  describe "untagged formality fallback" do
    it "picks garments with nil formality as last resort" do
      tagged = create(:garment, :top, user:, formality: "formal", name: "Tux Jacket")
      untagged = create(:garment, :top, user:, formality: nil, name: "Plain Tee")
      bottom = create(:garment, :bottom, user:, formality: "casual")
      day = call_engine([ tagged, untagged, bottom ], %w[casual]).first
      expect(day.top).to eq(untagged)
    end
  end
end
