# frozen_string_literal: true

module Wardrobe
  # Saves several garments at once and optionally queues their product images (design doc 4.2, D10).
  # Used by the starter import (onboarding) and receipts. Garments are saved right away; images follow
  # from Wardrobe::GenerateGarmentImageJob.
  #
  #   Wardrobe::AddGarments.call(user:, items: [{ name:, category:, color:, ... }], source: :receipt,
  #                              generate_images: true) # => Array<Garment>
  #
  # All items are saved or none: an invalid item raises ActiveRecord::RecordInvalid and nothing is kept.
  class AddGarments
    # Item keys that map straight onto garment columns. "color" is accepted as an alias for color_primary.
    ITEM_FIELDS = %w[name category sub_category color_primary color_secondary pattern material formality
                     seasonality gender brand size fit_notes price_cents source_url].freeze

    def self.call(user:, items:, source:, generate_images: true)
      new(user:, items:, source:, generate_images:).call
    end

    def initialize(user:, items:, source:, generate_images: true)
      @user = user
      @items = items
      @source = source.to_s
      @generate_images = generate_images
    end

    def call
      garments = Garment.transaction do
        @items.map { |item| Garment.create!(attributes_for(item)) }
      end
      enqueue_image_jobs(garments) if @generate_images
      garments
    end

    private

    # Jobs are queued only once every open transaction has committed, including a caller's outer one
    # (e.g. onboarding), so a job never looks for a garment that is not saved, and a rollback queues nothing.
    # The app keeps enqueue_after_transaction_commit off, so this is done explicitly.
    def enqueue_image_jobs(garments)
      ActiveRecord.after_all_transactions_commit do
        ActiveJob.perform_all_later(garments.map { Wardrobe::GenerateGarmentImageJob.new(_1.id) })
      end
    end

    def attributes_for(item)
      item = item.to_h.stringify_keys
      item["color_primary"] = item["color"] if item["color_primary"].blank?
      item.slice(*ITEM_FIELDS).merge(
        "user" => @user,
        "source" => @source,
        # pending while an image is on its way; placeholder when none was asked for (design doc 5.3)
        "image_status" => @generate_images ? "pending" : "placeholder"
      )
    end
  end
end
