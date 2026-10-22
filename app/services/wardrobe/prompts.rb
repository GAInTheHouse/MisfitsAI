# frozen_string_literal: true

module Wardrobe
  # Prompt text for wardrobe AI calls, kept in one place so specs can assert on it (design doc 12.2).
  module Prompts
    # Starter, manual and receipt product image (design doc 6.4). The wording must stay exact.
    GARMENT_IMAGE_INTRO = "Professional e-commerce product photo of a single garment, centered, pure white " \
                          "seamless background, soft studio lighting, subtle floor shadow, no hanger, no model, " \
                          "no hands, high detail fashion photography."
    GARMENT_IMAGE_OUTRO = "Full garment visible, crisp edges, photorealistic."
    BRAND_CLAUSE = "Brand-inspired silhouette only (do not render readable logos or trademark graphics): %s."

    module_function

    def garment_image(garment)
      [
        GARMENT_IMAGE_INTRO,
        "Garment category: #{garment.category}.",
        "Product style: #{garment.name}.",
        optional("Primary color: %s.", garment.color_primary),
        optional("Pattern: %s.", garment.pattern),
        optional("Material: %s.", garment.material),
        optional(BRAND_CLAUSE, garment.brand),
        GARMENT_IMAGE_OUTRO
      ].compact.join(" ")
    end

    def optional(template, value)
      format(template, value) if value.present?
    end
  end
end
