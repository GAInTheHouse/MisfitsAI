# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::PhotoIntake::Mapper do
  def item(overrides = {})
    { "item_type" => "crewneck sweater", "color" => "Cream", "pattern" => "solid", "material" => "wool",
      "fit_style" => "relaxed", "category" => "top", "sub_category" => "Crew Neck-Sweater", "formality" => "casual",
      "seasonality" => "cold", "brand" => "Uniqlo" }.merge(overrides)
  end

  def map(*items) = described_class.call("items" => items)

  it "maps an item onto draft attrs (design doc 6.6)" do
    expect(map(item).first).to include(
      "name" => "Crewneck Sweater", "item_type" => "crewneck sweater", "category" => "top",
      "sub_category" => "crew_neck_sweater", "color_primary" => "cream", "pattern" => nil, "material" => "wool",
      "fit_notes" => "relaxed", "formality" => "casual", "seasonality" => "cold", "brand" => "Uniqlo",
      "needs_confirmation" => false
    )
  end

  [ "solid", "None", "no pattern", "plain", "N/A", "" ].each do |pattern|
    it "treats the pattern #{pattern.inspect} as solid (nil)" do
      expect(map(item("pattern" => pattern)).first["pattern"]).to be_nil
    end
  end

  it "keeps a real pattern, downcased" do
    expect(map(item("pattern" => "Pinstripe")).first["pattern"]).to eq("pinstripe")
  end

  it "keeps the brand ([CHANGE] in 6.6: the original dropped it)" do
    expect(map(item("brand" => "Levi's")).first["brand"]).to eq("Levi's")
  end

  it "sets invalid formality and seasonality to nil" do
    expect(map(item("formality" => "fancy", "seasonality" => "monsoon")).first.values_at("formality", "seasonality"))
      .to eq([ nil, nil ])
  end

  it "falls back to top for an invalid category and flags it for review" do
    expect(map(item("category" => "spacesuit")).first.values_at("category", "needs_confirmation")).to eq([ "top", true ])
  end

  it "skips items without an item_type" do
    expect(map(item("item_type" => " "), item("item_type" => nil), item).size).to eq(1)
  end

  it "creates at most VISION_MAX_GARMENT_IMAGES drafts (default 6)" do
    expect(map(*Array.new(8) { item }).size).to eq(6)
    with_env("VISION_MAX_GARMENT_IMAGES" => "2") { expect(map(*Array.new(8) { item }).size).to eq(2) }
  end

  describe "confidence ([DEVIATION]: optional schema field)" do
    it "stores it clamped to 0..1 and flags values under 0.75" do
      expect(map(item("confidence" => 0.4)).first.values_at("confidence", "needs_confirmation")).to eq([ 0.4, true ])
      expect(map(item("confidence" => 0.9)).first.values_at("confidence", "needs_confirmation")).to eq([ 0.9, false ])
      expect(map(item("confidence" => 7)).first["confidence"]).to eq(1.0)
    end

    it "ignores a missing or non-numeric confidence" do
      expect(map(item("confidence" => "very")).first.values_at("confidence", "needs_confirmation")).to eq([ nil, false ])
    end
  end

  it "trims names to 80 characters" do
    expect(map(item("item_type" => "x" * 100)).first["name"].length).to eq(80)
  end

  it "accepts symbol keys" do
    expect(described_class.call(items: [ item.transform_keys(&:to_sym) ]).first["name"]).to eq("Crewneck Sweater")
  end

  it "returns no drafts for an empty list" do
    expect(map).to eq([])
  end

  [ nil, "text", [], { "items" => "nope" }, { "kind" => "garment_extraction" } ].each do |response|
    it "raises for the malformed response #{response.inspect}" do
      expect { described_class.call(response) }.to raise_error(Wardrobe::PhotoIntake::MalformedResponseError)
    end
  end

  it "skips list entries that are not objects" do
    expect(described_class.call("items" => [ "sweater", 3, item ]).size).to eq(1)
  end
end
