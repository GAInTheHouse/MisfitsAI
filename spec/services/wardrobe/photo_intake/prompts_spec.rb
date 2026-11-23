# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::PhotoIntake::Prompts do
  it "keeps the extraction prompt stable (product contract)" do
    expect(described_class::EXTRACTION).to start_with("You are a fashion-vision parser.")
    expect(described_class::EXTRACTION).to include("Identify each distinct garment item")
  end

  it "requires the documented fields and keeps confidence optional" do
    item = described_class::GARMENT_SCHEMA.dig(:properties, :items, :items)
    expect(item[:required]).to eq(%w[item_type color category formality seasonality])
    expect(item.dig(:properties, :category, :enum)).to eq(Garment::CATEGORIES)
    expect(item.dig(:properties, :confidence, :nullable)).to be(true)
  end

  describe ".reference_flatlay" do
    it "names the garment and asks for a photo-conditioned flat lay" do
      attrs = { "color_primary" => "blue", "item_type" => "straight jeans" }
      prompt = described_class.reference_flatlay(attrs)
      expect(prompt).to include("reference photo", "straight jeans", "blue", "white background")
    end
  end

  describe ".product_image (design doc 6.6, exact)" do
    it "includes every part when present" do
      attrs = { "color_primary" => "cream", "pattern" => "cable-knit", "material" => "wool", "item_type" => "crewneck sweater",
                "fit_style" => "relaxed" }
      expect(described_class.product_image(attrs)).to eq(
        "product photo of a cream cable-knit wool crewneck sweater relaxed, isolated on a pure white background, " \
        "studio lighting, flat lay, high resolution, fashion photography"
      )
    end

    it "leaves out blank parts" do
      expect(described_class.product_image("color_primary" => "blue", "item_type" => "straight jeans")).to eq(
        "product photo of a blue straight jeans, isolated on a pure white background, studio lighting, flat lay, " \
        "high resolution, fashion photography"
      )
    end
  end
end
