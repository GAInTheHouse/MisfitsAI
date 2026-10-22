# frozen_string_literal: true

module Wardrobe
  # Photo intake, step 1 (design doc 6.6): asks Gemini which garments are in the uploaded photo, creates up
  # to six drafts and queues their product images. The batch always ends ready or failed, and the source
  # photo is deleted once it has (only the generated images are kept).
  class ExtractGarmentsJob < ApplicationJob
    include IntakeBatchJobSupport

    queue_as :ai_text

    # One run per batch at a time (Solid Queue): a duplicate enqueue cannot analyze the same photo twice.
    limits_concurrency key: ->(batch_id) { "intake-batch-#{batch_id}" }, to: 1, duration: 10.minutes

    ANALYZE_FAILED = "We couldn't analyze that photo right now. Please try again."
    PROCESSING_FAILED = ANALYZE_FAILED # used by IntakeBatchJobSupport's catch-all
    NO_GARMENTS = "No garments detected from image. Please upload a clearer outfit photo."
    QUOTA_REACHED = "You've reached today's photo analysis limit. Please try again tomorrow."
    UNREADABLE = "We couldn't read that photo. Please upload a JPEG, PNG, WebP or HEIC image."

    STARTED_PROGRESS = 10
    DRAFTS_READY_PROGRESS = 30

    # The catch-all (fail and re-raise) comes from IntakeBatchJobSupport; these specific handlers win over it.
    rescue_from(Ai::ContentBlockedError, Ai::DisabledError, PhotoIntake::MalformedResponseError) do |error|
      Rails.logger.info("[Wardrobe::ExtractGarmentsJob] batch #{arguments.first}: #{error.class}")
      fail_batch(ANALYZE_FAILED)
    end
    rescue_from(Ai::QuotaExceededError) { fail_batch(QUOTA_REACHED) }
    rescue_from(Media::InvalidImageError, ActiveStorage::FileNotFoundError) { fail_batch(UNREADABLE) }
    retry_on Ai::TransientError, wait: :polynomially_longer, attempts: 3 do |job, _error|
      job.send(:fail_batch, ANALYZE_FAILED)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(batch_id)
      @batch = IntakeBatch.photos.find(batch_id)
      return if @batch.finished? # already analyzed; safe to run again
      return fail_batch(UNREADABLE) unless @batch.source_file.attached?

      @batch.mark_processing!(progress: STARTED_PROGRESS)
      # Downloaded to a temp file and read by libvips from disk, never loaded whole into Ruby memory.
      photo = @batch.source_file.open { |file| PhotoIntake::ImagePreparer.call(file.path) }
      response = Ai::Client.current.generate_json(
        kind: :garment_extraction, prompt: PhotoIntake::Prompts::EXTRACTION,
        schema: PhotoIntake::Prompts::GARMENT_SCHEMA, images: [ photo ], user: @batch.user
      )
      items = PhotoIntake::Mapper.call(response)
      return fail_batch(NO_GARMENTS) if items.empty?

      drafts = create_drafts(items)
      return if drafts.nil? # another run already finished this batch
      purge_source
      broadcast_batch
      ActiveRecord.after_all_transactions_commit do
        ActiveJob.perform_all_later(drafts.map { Wardrobe::GenerateDraftImageJob.new(_1.id) })
      end
    end

    private

    # Drafts and the "ready" status are committed together, under the batch lock: a run that dies in between
    # leaves nothing half-done, and a rerun (retry, or Solid Queue re-running a crashed worker's job) finds
    # the batch finished instead of adding the drafts a second time. Returns nil in that case.
    def create_drafts(items)
      @batch.with_lock do
        next nil if @batch.finished?

        drafts = items.each_with_index.map do |attrs, index|
          @batch.garment_drafts.create!(user: @batch.user, attrs: attrs, position: index, status: "pending")
        end
        @batch.update!(status: "ready", progress: DRAFTS_READY_PROGRESS, error: nil)
        drafts
      end
    end

    def batch_partial = "wardrobe/photo_intakes/batch"
  end
end
