# frozen_string_literal: true

module Receipts
  # Creates receipt batches and their drafts (design doc 6.12). Parsed items become garment_drafts whose
  # attrs hold name, brand, size, color_primary, category, price_cents, confidence, needs_confirmation and
  # source_line.
  module Intake
    NO_ITEMS = "We couldn't find any clothing items on that receipt."

    module_function

    # Pasted text, a text file or a PDF: parsed in the request (6.12 "Synchronous"). Nothing is stored as a file.
    def from_text(user:, text:, strategy:)
      items = TextParser.call(text)
      batch = user.intake_batches.create!(kind: "receipt", status: "processing", parser_strategy: strategy,
                                          extracted_text_preview: text.to_s.strip.presence)
      finish(batch, items)
    end

    # Adds drafts for the parsed items and marks the batch ready, or failed when there are none.
    def finish(batch, items)
      return batch.tap { _1.mark_failed!(NO_ITEMS) } if items.empty?

      IntakeBatch.transaction do
        items.each_with_index do |item, index|
          # A row that names no garment (a priced line like "Gift wrap $5") starts unselected.
          batch.garment_drafts.create!(user: batch.user, status: "ready", position: index, attrs: draft_attrs(item),
                                       selected: item["category_found"] != false)
        end
        batch.mark_ready!
      end
      batch
    end

    def draft_attrs(item)
      {
        "name" => item["name"].to_s.first(Garment::NAME_MAX_LENGTH),
        "brand" => item["brand"], "size" => item["size"],
        "color_primary" => item["color"].to_s.downcase.presence,
        "category" => item["category"],
        "price_cents" => item["price"] && (item["price"] * 100).round,
        "confidence" => item["confidence"], "needs_confirmation" => item["needs_confirmation"],
        "source_line" => item["source_line"]
      }
    end
  end
end
