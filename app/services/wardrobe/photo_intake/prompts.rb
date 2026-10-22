# frozen_string_literal: true

module Wardrobe
  module PhotoIntake
    # Prompt text and response schema for photo intake (design doc 6.6, 12.2). The wording must stay exact.
    module Prompts
      EXTRACTION = <<~PROMPT.strip.freeze
        You are a fashion-vision parser. The input is a personal photo; garments may be partially visible.
        Identify each distinct garment item and return one entry per garment item you can see.
        Sub-category reference lists (use these exact values when applicable):
          Tops: t-shirt, shirt, blouse, sweater, cardigan, hoodie, sweatshirt, blazer, vest,
                halter_neck, crop_top, tank_top, bodysuit, turtleneck, polo, henley
          Bottoms: jeans, trousers, pants, skirt, shorts, leggings, sweatpants, cargo pants,
                   dress pants, wide-leg pants, culottes
          Other: dress, jumpsuit, coat, jacket, parka, cardigan, sneakers, boots, heels,
                 loafers, sandals, bag, belt, scarf, hat, sunglasses
        Rules:
        - If uncertain, still choose the closest valid category.
        - item_type must be a concrete garment name (e.g. crewneck sweater, high-waist trousers).
        - When no pattern is visible, set pattern to "solid" (do not use values like "none" or "no pattern").
        - Recognized brands include (non-exhaustive): Zara, H&M, Urban Revivo, Uniqlo, Mango, SHEIN,
          Abercrombie & Fitch, Levi's, Ralph Lauren, Tommy Hilfiger, Nike, Adidas, Lululemon.
      PROMPT

      # Design doc 6.6 schema. [DEVIATION] adds the optional "confidence" field (not in required), so the
      # review can flag uncertain items; the prompt text above is unchanged.
      GARMENT_SCHEMA = {
        type: "OBJECT",
        properties: {
          items: { type: "ARRAY", items: { type: "OBJECT", properties: {
            item_type:    { type: "STRING" },
            color:        { type: "STRING" },
            pattern:      { type: "STRING" },
            material:     { type: "STRING", nullable: true },
            fit_style:    { type: "STRING", nullable: true },
            category:     { type: "STRING", enum: %w[top bottom dress outerwear shoes accessory] },
            sub_category: { type: "STRING" },
            formality:    { type: "STRING", enum: %w[casual smart_casual business formal] },
            seasonality:  { type: "STRING", enum: %w[hot mild cold all_season] },
            brand:        { type: "STRING", nullable: true },
            confidence:   { type: "NUMBER", nullable: true,
                            description: "How sure you are about this item, from 0 to 1." }
          }, required: %w[item_type color category formality seasonality] } }
        },
        required: %w[items]
      }.freeze

      module_function

      # Draft product image (design doc 6.6, exact): bracketed parts are left out when blank.
      def product_image(attrs)
        attrs = attrs.to_h.stringify_keys
        subject = [ attrs["color_primary"], attrs["pattern"], attrs["material"], attrs["item_type"].presence || attrs["name"],
                    attrs["fit_style"] ].compact_blank.join(" ")
        "product photo of a #{subject}, isolated on a pure white background, studio lighting, flat lay, " \
          "high resolution, fashion photography"
      end
    end
  end
end
