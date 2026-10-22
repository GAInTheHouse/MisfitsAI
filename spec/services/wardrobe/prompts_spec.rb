# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::Prompts do
  describe ".garment_image (design doc 6.4, exact wording)" do
    it "includes every optional clause when the garment has those details" do
      garment = build(:garment, category: "top", name: "White Oxford Shirt", color_primary: "white",
                                pattern: "pinstripe", material: "cotton", brand: "Uniqlo")

      expect(described_class.garment_image(garment)).to eq(
        "Professional e-commerce product photo of a single garment, centered, pure white seamless background, " \
        "soft studio lighting, subtle floor shadow, no hanger, no model, no hands, high detail fashion photography. " \
        "Garment category: top. Product style: White Oxford Shirt. Primary color: white. Pattern: pinstripe. " \
        "Material: cotton. Brand-inspired silhouette only (do not render readable logos or trademark graphics): " \
        "Uniqlo. Full garment visible, crisp edges, photorealistic."
      )
    end

    it "leaves out the optional clauses that have no value" do
      garment = build(:garment, category: "bottom", name: "Khaki Chinos")

      expect(described_class.garment_image(garment)).to eq(
        "Professional e-commerce product photo of a single garment, centered, pure white seamless background, " \
        "soft studio lighting, subtle floor shadow, no hanger, no model, no hands, high detail fashion photography. " \
        "Garment category: bottom. Product style: Khaki Chinos. Full garment visible, crisp edges, photorealistic."
      )
    end

    it "inserts values literally, even ones containing format characters" do
      garment = build(:garment, name: "100% Linen Shirt", material: "100% linen")
      expect(described_class.garment_image(garment)).to include("Product style: 100% Linen Shirt.",
                                                               "Material: 100% linen.")
    end
  end
end
