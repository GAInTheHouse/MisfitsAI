# frozen_string_literal: true

module Wardrobe
  # Photo intake, step 2 (design doc 6.6): a product image for one draft. A failed image leaves the draft
  # ready without an image, so it can still be committed with the category placeholder.
  # If the draft is committed before its image is done, the image goes to the garment it became (the one in
  # attrs["garment_id"], while that garment still waits for an image), so the AI call is not wasted.
  class GenerateDraftImageJob < ApplicationJob
    queue_as :ai_images

    limits_concurrency key: ->(draft_id) { "draft-image-#{draft_id}" }, to: 1, duration: 10.minutes

    IMAGE_UNAVAILABLE = "Product image unavailable"

    rescue_from(StandardError) do |error|
      finish(error: IMAGE_UNAVAILABLE)
      raise error
    end
    rescue_from(Ai::DisabledError, Ai::QuotaExceededError, Ai::ContentBlockedError) { finish(error: IMAGE_UNAVAILABLE) }
    retry_on Ai::TransientError, wait: :polynomially_longer, attempts: 3 do |job, _error|
      job.send(:finish, error: IMAGE_UNAVAILABLE)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(draft_id)
      @draft = GarmentDraft.find(draft_id)
      return unless @draft.pending? || waiting_garment # nothing needs this image: no AI call

      image = Ai::Client.current.generate_image(
        kind: :garment_image, prompt: PhotoIntake::Prompts.product_image(@draft.attrs), user: @draft.user
      )
      jpeg = Media::ImageNormalizer.to_square_jpeg(image.bytes, size: ENV.fetch("GARMENT_ASSET_SIZE", 512).to_i)
      garment = attach(jpeg)
      garment ? Wardrobe::GarmentBroadcasts.image_changed(garment) : finish
    end

    private

    # The garment this draft became while its image was still being made, if that garment still waits for one.
    def waiting_garment
      return unless @draft.committed? && @draft.attrs["garment_id"]

      Garment.find_by(id: @draft.attrs["garment_id"], image_status: "pending")
    end

    # Attaches to the draft if it is still pending, else to the garment it became. Returns that garment, or nil.
    def attach(jpeg)
      file = -> { { io: StringIO.new(jpeg), filename: "draft-#{@draft.id}.jpg", content_type: "image/jpeg" } }
      @draft.with_lock do
        if @draft.pending?
          @draft.image.attach(**file.call)
          nil
        else
          garment = waiting_garment
          garment&.with_lock do
            unless garment.image.attached? && garment.image_status == "ready" # never overwrite a ready image
              garment.image.attach(**file.call)
              garment.update!(image_status: "ready")
            end
          end
          garment
        end
      end
    end

    # Ready (with or without an image), batch progress updated, image area and progress broadcast.
    def finish(error: nil)
      draft = @draft || GarmentDraft.find_by(id: arguments.first)
      return unless draft

      draft.with_lock { draft.update!(status: "ready", error: error) if draft.pending? }
      batch = draft.intake_batch
      update_progress(batch)
      broadcast(draft, batch)
    end

    def update_progress(batch)
      drafts = batch.garment_drafts
      done = drafts.where.not(status: "pending").count
      total = drafts.count
      progress = ExtractGarmentsJob::DRAFTS_READY_PROGRESS +
                 ((100 - ExtractGarmentsJob::DRAFTS_READY_PROGRESS) * done / [ total, 1 ].max)
      batch.update!(progress: progress)
    end

    def broadcast(draft, batch)
      stream = [ draft.user, :wardrobe ]
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: ActionView::RecordIdentifier.dom_id(draft, :image),
                                                         partial: "wardrobe/photo_intakes/draft_image", locals: { draft: draft })
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: ActionView::RecordIdentifier.dom_id(batch, :progress),
                                                         partial: "wardrobe/photo_intakes/progress", locals: { batch: batch })
    end
  end
end
