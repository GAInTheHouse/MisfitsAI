# frozen_string_literal: true

module Wardrobe
  # Generates a product image for a garment (design doc 6.4), used by manual add, the starter import and
  # receipts. It always leaves the garment ready, placeholder or failed, never stuck pending (design doc 2.4).
  class GenerateGarmentImageJob < ApplicationJob
    # Imagen calls run one at a time in production (config/queue.yml), which spaces them out.
    queue_as :ai_images

    # At most one job per garment runs at a time (Solid Queue): a second one waits, then finds the image ready
    # and stops without calling the AI. The duration outlasts a slow Imagen call (up to 120 s; no HTTP-level retries).
    limits_concurrency key: ->(garment_id) { "garment-image-#{garment_id}" }, to: 1, duration: 10.minutes

    # Handlers declared later win, so the catch-all comes first.
    rescue_from(StandardError) do |error|
      finish("failed")
      raise error
    end

    retry_on Ai::TransientError, wait: :polynomially_longer, attempts: 3 do |job, _error|
      job.send(:finish, "failed")
    end

    # Our own limits and the safety filter: keep the placeholder and do not retry (design doc 6.4 rule 4).
    rescue_from(Ai::DisabledError, Ai::QuotaExceededError, Ai::ContentBlockedError) { finish("placeholder") }

    discard_on ActiveRecord::RecordNotFound

    def perform(garment_id)
      @garment = Garment.find(garment_id)
      return if @garment.image.attached? && @garment.image_status == "ready" # already done; safe to rerun

      image = Ai::Client.current.generate_image(
        kind: :garment_image, prompt: Wardrobe::Prompts.garment_image(@garment), user: @garment.user
      )
      jpeg = Media::ImageNormalizer.to_square_jpeg(image.bytes, size: ENV.fetch("GARMENT_ASSET_SIZE", 512).to_i)
      attached = @garment.with_lock do
        # Another run may have finished while the AI call was in flight: keep its image, discard this one.
        next false if @garment.image.attached? && @garment.image_status == "ready"

        @garment.image.attach(io: StringIO.new(jpeg), filename: "garment-#{@garment.id}.jpg",
                              content_type: "image/jpeg")
        true
      end
      attached ? finish("ready") : broadcast(@garment)
    end

    private

    def finish(status)
      garment = @garment || Garment.find_by(id: arguments.first)
      return unless garment

      garment.update!(image_status: status)
      broadcast(garment)
    end

    def broadcast(garment)
      Wardrobe::GarmentBroadcasts.image_changed(garment)
    end
  end
end
