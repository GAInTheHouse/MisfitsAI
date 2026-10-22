# frozen_string_literal: true

module Wardrobe
  # Daily cleanup (design doc 5.3): removes intake batches with no activity for 24 hours (IntakeBatch.stale),
  # with their drafts and files. Committed drafts no longer hold images (Commit moves them to the garments),
  # so a garment's image is never touched.
  #
  # Each batch is locked (the same lock Commit takes) and checked again before it is removed, so a batch that
  # became active meanwhile is kept. A batch already gone is skipped, so running twice is harmless.
  class PurgeStaleDraftsJob < ApplicationJob
    queue_as :default

    def perform(now = Time.current)
      IntakeBatch.stale(now).find_each do |batch|
        batch.with_lock do
          batch.destroy! if IntakeBatch.stale(now).exists?(batch.id)
        end
      rescue ActiveRecord::RecordNotFound
        next # removed by someone else meanwhile
      end
    end
  end
end
