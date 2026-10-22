# frozen_string_literal: true

module Receipts
  # Reads a receipt photo or screenshot with Gemini (design doc 6.12 "image_vision") and turns its items into
  # drafts. The batch always ends ready or failed, and the uploaded image is deleted once it has.
  class ParseImageJob < ApplicationJob
    include IntakeBatchJobSupport

    queue_as :ai_text

    READ_FAILED = "We couldn't read that receipt right now. Please try again."
    PROCESSING_FAILED = READ_FAILED # used by IntakeBatchJobSupport's catch-all
    QUOTA_REACHED = "You've reached today's receipt reading limit. Please try again tomorrow."
    UNREADABLE = "We couldn't read that image. Please upload a receipt photo, screenshot or PDF."
    MAX_SIDE = 2400 # receipts need more pixels than outfit photos for small print

    rescue_from(Ai::ContentBlockedError, Ai::DisabledError, MalformedResponseError) do |error|
      Rails.logger.info("[Receipts::ParseImageJob] batch #{arguments.first}: #{error.class}")
      fail_batch(READ_FAILED)
    end
    rescue_from(Ai::QuotaExceededError) { fail_batch(QUOTA_REACHED) }
    rescue_from(Media::InvalidImageError, ActiveStorage::FileNotFoundError) { fail_batch(UNREADABLE) }
    retry_on Ai::TransientError, wait: :polynomially_longer, attempts: 3 do |job, _error|
      job.send(:fail_batch, READ_FAILED)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(batch_id)
      @batch = IntakeBatch.receipts.find(batch_id)
      return if @batch.finished? # already read; safe to run again
      return fail_batch(UNREADABLE) unless @batch.source_file.attached?

      @batch.mark_processing!(progress: 10)
      image = @batch.source_file.open do |file|
        Wardrobe::PhotoIntake::ImagePreparer.call(file.path, max_side: MAX_SIDE)
      end
      items = VisionParser.call(image: image, user: @batch.user)
      Intake.finish(@batch, items)
      purge_source
      broadcast_batch
    end

    private

    def batch_partial = "wardrobe/receipts/batch"
  end
end
