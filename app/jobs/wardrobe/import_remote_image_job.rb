# frozen_string_literal: true

require "vips"

module Wardrobe
  # Downloads the image of a picked search result into storage instead of hotlinking it (design doc 6.5, D13).
  # The URL is untrusted: it goes through Media::SafeFetcher, and the bytes must be an allowed image type.
  # A temporary failure (timeout, network error, HTTP 408/429/5xx) is retried, three attempts in all; any
  # other download or format problem, or the last failed attempt, leaves the category placeholder (6.5).
  class ImportRemoteImageJob < ApplicationJob
    queue_as :default

    # One import per garment at a time; a ready image is never overwritten (same guards as image generation).
    limits_concurrency key: ->(garment_id, _url) { "garment-image-#{garment_id}" }, to: 1, duration: 5.minutes

    ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
    MAX_BYTES = 10.megabytes
    TIMEOUT = 10

    # Handlers declared later win, so the catch-all comes first.
    rescue_from(StandardError) do |error|
      finish("placeholder")
      raise error
    end
    rescue_from(Media::UnsafeUrlError, Media::FetchError, Media::InvalidImageError, Vips::Error) do |error|
      Rails.logger.info("[Wardrobe::ImportRemoteImageJob] garment #{arguments.first}: #{error.class}")
      finish("placeholder")
    end
    retry_on Media::TransientFetchError, wait: :polynomially_longer, attempts: 3 do |job, error|
      Rails.logger.info("[Wardrobe::ImportRemoteImageJob] garment #{job.arguments.first}: gave up after #{error.class}")
      job.send(:finish, "placeholder")
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(garment_id, image_url)
      @garment = Garment.find(garment_id)
      return if @garment.image.attached? && @garment.image_status == "ready"

      image = Media::SafeFetcher.fetch(image_url, max_bytes: MAX_BYTES, timeout: TIMEOUT)
      Media::ImageNormalizer.sniff!(image.bytes, allowed: ALLOWED_TYPES)
      jpeg = Media::ImageNormalizer.to_square_jpeg(image.bytes, size: ENV.fetch("GARMENT_ASSET_SIZE", 512).to_i)

      attached = @garment.with_lock do
        next false if @garment.image.attached? && @garment.image_status == "ready"

        @garment.image.attach(io: StringIO.new(jpeg), filename: "garment-#{@garment.id}.jpg", content_type: "image/jpeg")
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
      stream = [ garment.user, :wardrobe ]
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: garment, partial: "garments/garment",
                                                         locals: { garment: garment })
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: ActionView::RecordIdentifier.dom_id(garment, :thumb),
                                                         partial: "garments/thumb", locals: { garment: garment })
    end
  end
end
