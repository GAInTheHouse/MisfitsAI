# frozen_string_literal: true

module Receipts
  # Reads a receipt photo or screenshot with Gemini (design doc 6.12 "image_vision"), then normalizes items
  # to the TextParser item shape.
  #
  #   VisionParser.call(image:, user:) # => Array<Hash>; raises Ai::Error or Receipts::MalformedResponseError
  class VisionParser
    def self.call(image:, user:)
      response = Ai::Client.current.generate_json(
        kind: :receipt_extraction, prompt: Prompts::VISION, schema: Prompts::RECEIPT_SCHEMA, images: [ image ], user: user
      )
      normalize(response)
    end

    # 6.12 "Normalize the results": drop nameless items, infer invalid categories, clamp or compute confidence.
    def self.normalize(response)
      items = response.is_a?(Hash) ? (response["items"] || response[:items]) : nil
      raise MalformedResponseError, "items missing" unless items.is_a?(Array)

      items.filter_map do |raw|
        next unless raw.is_a?(Hash)

        raw = raw.stringify_keys
        name = raw["name"].to_s.squish
        next if name.blank?

        category = raw["category"].to_s.downcase.presence_in(Garment::CATEGORIES) || TextParser.infer_category(name)
        price = number(raw["price"])&.round(2)
        brand, size, color = raw.values_at("brand", "size", "color").map { _1.to_s.squish.presence }
        confidence = number(raw["confidence"])&.clamp(0.0, 0.99)&.round(2) ||
                     TextParser.confidence_for(category_found: true, price:, size:, color:, brand:)

        { "name" => name.first(Garment::NAME_MAX_LENGTH), "brand" => brand, "size" => size, "color" => color,
          "category" => category, "price" => price, "confidence" => confidence,
          "needs_confirmation" => confidence < TextParser::LOW_CONFIDENCE, "source_line" => nil }
      end
    end

    def self.number(value)
      value.is_a?(Numeric) ? value.to_f : Float(value.to_s, exception: false)
    end
    private_class_method :number
  end
end
