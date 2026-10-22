# frozen_string_literal: true

module Receipts
  # Receipt vision prompt and response schema (design doc 6.12, 12.2). The wording must stay exact.
  module Prompts
    VISION = <<~PROMPT.strip.freeze
      You are a receipt parser for a wardrobe app.
      Given a retail receipt screenshot/photo, extract ONLY clothing/accessory line items.
      Rules:
      - Exclude subtotal, total, tax, shipping, discounts, and payment lines.
      - Include only apparel, shoes, and accessories.
      - Use null for unknown fields.
      - confidence must be between 0 and 1.
    PROMPT

    RECEIPT_SCHEMA = {
      type: "OBJECT",
      properties: {
        items: { type: "ARRAY", items: { type: "OBJECT", properties: {
          name:       { type: "STRING" },
          brand:      { type: "STRING", nullable: true },
          size:       { type: "STRING", nullable: true },
          color:      { type: "STRING", nullable: true },
          category:   { type: "STRING", enum: %w[top bottom dress outerwear shoes accessory] },
          price:      { type: "NUMBER", nullable: true },
          confidence: { type: "NUMBER" }
        }, required: %w[name category] } }
      },
      required: %w[items]
    }.freeze
  end
end
