# frozen_string_literal: true

module Receipts
  # "Add selected" for a receipt batch (design doc 6.12): applies the review edits, then adds the selected
  # drafts through Wardrobe::AddGarments (source "receipt"), with product images when asked.
  #
  #   Commit.call(batch:, edits: { draft_id => { "selected", "name", "brand", "size", "color_primary",
  #                                               "category", "price" } }, generate_images: true)
  #   # => Array<Garment>; raises ActiveRecord::RecordInvalid or Receipts::InvalidEditError (nothing saved)
  #
  # Runs under the batch lock on committable drafts only, so committing twice never duplicates garments.
  class Commit
    EDITABLE = %w[name brand size color_primary category price].freeze
    PRICE_RE = /\A\$?\s*(\d{1,6}(?:[.,]\d{1,2})?)\z/
    INVALID_PRICE = "Price must be a number like 39.90"

    def self.call(batch:, edits: {}, generate_images: true)
      new(batch:, edits:, generate_images:).call
    end

    def initialize(batch:, edits:, generate_images:)
      @batch = batch
      @edits = edits
      @generate_images = generate_images
    end

    def call
      @batch.with_lock do
        Wardrobe::DraftEdits.apply(batch: @batch, edits: @edits, fields: EDITABLE) do |_draft, changes|
          changes["price_cents"] = price_cents(changes.delete("price")) if changes.key?("price")
          changes["color_primary"] = changes["color_primary"]&.downcase if changes.key?("color_primary")
        end
        drafts = @batch.garment_drafts.committable.ordered.lock.to_a
        garments = Wardrobe::AddGarments.call(user: @batch.user, items: drafts.map { item_for(_1) },
                                              source: :receipt, generate_images: @generate_images)
        drafts.each { _1.update!(status: "committed") }
        garments
      end
    end

    private

    def item_for(draft)
      attrs = draft.garment_attributes
      cents = attrs["price_cents"]
      # 6.12: "fit_notes gets "Receipt price: $%.2f" when a price exists"
      attrs.merge("fit_notes" => cents ? format("Receipt price: $%.2f", cents / 100.0) : nil).compact
    end

    def price_cents(value)
      return if value.blank?

      match = PRICE_RE.match(value.to_s.strip)
      raise InvalidEditError.new(INVALID_PRICE) unless match

      (match[1].tr(",", ".").to_f * 100).round
    end
  end
end
