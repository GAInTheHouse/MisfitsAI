# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::PhotoIntake::Prompts do
  it "matches the design doc 6.6 extraction prompt character for character" do
    doc = Rails.root.join("docs/ruby_rewrite_design_doc_v2.md").read
    documented = doc[/\*\*Extraction prompt\*\*.*?```text\n(.*?)\n```/m, 1]
    expect(documented).to be_present
    expect(described_class::EXTRACTION).to eq(documented)
  end

  it "requires the documented fields and keeps confidence optional" do
    item = described_class::GARMENT_SCHEMA.dig(:properties, :items, :items)
    expect(item[:required]).to eq(%w[item_type color category formality seasonality])
    expect(item.dig(:properties, :category, :enum)).to eq(Garment::CATEGORIES)
    expect(item.dig(:properties, :confidence, :nullable)).to be(true)
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
