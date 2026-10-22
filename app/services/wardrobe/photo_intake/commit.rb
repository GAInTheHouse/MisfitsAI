# frozen_string_literal: true

module Wardrobe
  module PhotoIntake
    # Adds the selected drafts of a photo batch to the wardrobe (design doc 6.6 "Commit").
    #
    #   Commit.call(batch:, edits: { draft_id => { "selected" =>, "name" =>, "category" => } })
    #   # => Array<Garment> (empty when nothing is left to add); raises ActiveRecord::RecordInvalid
    #
    # - Runs under a lock on the batch and only uses committable drafts, so committing twice (double click,
    #   two tabs) never creates a garment twice.
    # - The draft's image blob moves to the garment: attached to the garment, then detached from the draft
    #   without purging, so discarding or purging the batch later cannot delete the garment's image.
    # - A draft whose image is still being generated becomes a pending garment. The draft remembers it
    #   (attrs["garment_id"]) and Wardrobe::GenerateDraftImageJob hands its image over when it finishes, so one
    #   AI call serves both. A delayed GenerateGarmentImageJob is the safety net if that job never delivers
    #   (failure, crash, purge): it finds the garment ready and stops, or makes the image itself.
    class Commit
      EDITABLE = %w[name category].freeze
      SAFETY_NET_DELAY = 10.minutes # matches the image jobs' concurrency window

      def self.call(batch:, edits: {})
        new(batch:, edits:).call
      end

      def initialize(batch:, edits:)
        @batch = batch
        @edits = edits.to_h.transform_keys(&:to_s)
      end

      def call
        garments = []
        needs_image = []
        @batch.with_lock do
          Wardrobe::DraftEdits.apply(batch: @batch, edits: @edits, fields: EDITABLE)
          @batch.garment_drafts.committable.ordered.lock.each do |draft|
            garment = Garment.create!(draft.garment_attributes.merge(user: @batch.user, source: "photo",
                                                                     image_status: image_status_for(draft)))
            if draft.image.attached?
              garment.image.attach(draft.image.blob)
              draft.image.detach
            elsif draft.pending?
              needs_image << garment
            end
            draft.update!(status: "committed", attrs: draft.attrs.merge("garment_id" => garment.id))
            garments << garment
          end
        end
        ActiveRecord.after_all_transactions_commit do
          needs_image.each { Wardrobe::GenerateGarmentImageJob.set(wait: SAFETY_NET_DELAY).perform_later(_1.id) }
        end
        garments
      end

      private

      def image_status_for(draft)
        return "ready" if draft.image.attached?

        draft.pending? ? "pending" : "placeholder"
      end
    end
  end
end
