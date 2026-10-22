# frozen_string_literal: true

module Wardrobe
  # Onboarding's "Build My Wardrobe" step (design doc 4.2, 6.3): saves the reviewed starter items right away
  # with source "starter" and image_status "pending", and queues one product image job per garment.
  #
  #   Wardrobe::StarterImport.call(user:, items: [{ name:, category:, color:, size:, formality:, seasonality: }])
  #   # => Array<Garment>
  #
  # Items may also carry sub_category (design doc 12.3 starter catalog). Season defaults to all_season.
  # It runs inside the onboarding request, so it only writes rows and enqueues jobs: no AI calls.
  class StarterImport
    DEFAULT_SEASONALITY = "all_season"

    def self.call(user:, items:)
      items = items.map do |item|
        item = item.to_h.stringify_keys
        item.merge("seasonality" => item["seasonality"].presence || DEFAULT_SEASONALITY)
      end
      Wardrobe::AddGarments.call(user: user, items: items, source: :starter, generate_images: true)
    end
  end
end
