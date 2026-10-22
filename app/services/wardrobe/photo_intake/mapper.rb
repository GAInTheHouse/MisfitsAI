# frozen_string_literal: true

module Wardrobe
  module PhotoIntake
    # Turns the garment_extraction response into draft attrs (design doc 6.6 "Mapping").
    #
    #   Mapper.call({ "items" => [...] }) # => Array<Hash> (string keys, at most VISION_MAX_GARMENT_IMAGES)
    #   raises MalformedResponseError when the response is not { "items" => [ {...}, ... ] }
    class Mapper
      SOLID_PATTERNS = [ "solid", "none", "no pattern", "plain", "n/a" ].freeze
      LOW_CONFIDENCE = 0.75 # same threshold as receipts (design doc 6.12)

      def self.call(response)
        new.call(response)
      end

      def call(response)
        items = response.is_a?(Hash) ? (response["items"] || response[:items]) : nil
        raise MalformedResponseError, "items missing" unless items.is_a?(Array)

        items.filter_map { |item| map(item.stringify_keys) if item.is_a?(Hash) }.first(max_drafts)
      end

      private

      def map(item)
        item_type = item["item_type"].to_s.squish
        return if item_type.blank?

        category = item["category"].to_s.strip.downcase
        category_guessed = !Garment::CATEGORIES.include?(category)
        confidence = confidence_from(item["confidence"])

        {
          "name" => item_type.titleize.first(Garment::NAME_MAX_LENGTH).strip,
          "item_type" => item_type.downcase,
          "category" => category_guessed ? "top" : category,
          "sub_category" => Garment.normalize_kind(item["sub_category"]),
          "color_primary" => item["color"].to_s.strip.downcase.presence,
          "pattern" => pattern_from(item["pattern"]),
          "material" => item["material"].to_s.strip.presence,
          "fit_notes" => item["fit_style"].to_s.strip.presence,
          "fit_style" => item["fit_style"].to_s.strip.downcase.presence,
          "formality" => item["formality"].to_s.presence_in(Garment::FORMALITIES),
          "seasonality" => item["seasonality"].to_s.presence_in(Garment::SEASONALITIES),
          "brand" => item["brand"].to_s.strip.presence,
          "confidence" => confidence,
          "needs_confirmation" => category_guessed || (confidence && confidence < LOW_CONFIDENCE) || false
        }
      end

      def pattern_from(value)
        pattern = value.to_s.strip.downcase
        pattern unless pattern.blank? || SOLID_PATTERNS.include?(pattern)
      end

      def confidence_from(value)
        Float(value).clamp(0.0, 1.0).round(2) if value.is_a?(Numeric) || value.to_s.match?(/\A\d+(\.\d+)?\z/)
      end

      def max_drafts
        ENV.fetch("VISION_MAX_GARMENT_IMAGES", 6).to_i.clamp(1, 20)
      end
    end
  end
end
