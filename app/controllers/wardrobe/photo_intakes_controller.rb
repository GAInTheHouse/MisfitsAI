# frozen_string_literal: true

module Wardrobe
  # Photo AI (design doc 6.6): upload an outfit photo, then review the detected garments.
  # Views render inside the "photo_intake" Turbo Frame of the wardrobe page (and stand alone without JS).
  class PhotoIntakesController < ApplicationController
    include IntakeUpload

    MAX_BYTES = 15.megabytes
    EMPTY = "Uploaded file is empty"
    TOO_LARGE = "Image too large"
    NOT_AN_IMAGE = "Please upload a JPEG, PNG, WebP or HEIC image"
    MISSING = "Choose a photo to upload"

    before_action :require_feature!
    before_action :set_batch, only: :show

    def new; end

    def create
      upload = params[:photo]
      error = upload_error(upload)
      return render_new_error(error) if error

      upload.rewind
      # Stored first, then queued (IntakeUpload); Active Storage identifies the content type from the bytes.
      batch = create_upload_batch(file: upload, job: Wardrobe::ExtractGarmentsJob, kind: "photo")
      redirect_to wardrobe_photo_intake_path(batch)
    end

    def show; end

    private

    def require_feature!
      head :not_found unless Feature.enabled?(:photo_intake)
    end

    def set_batch
      @batch = current_user.intake_batches.photos.find(params[:id])
    end

    # Checks the upload by size and by its bytes (magic number), never by its name or Content-Type.
    def upload_error(upload)
      return MISSING unless upload.respond_to?(:read) && upload.respond_to?(:size)
      return EMPTY if upload.size.zero?
      return TOO_LARGE if upload.size > MAX_BYTES

      Media::ImageNormalizer.sniff!(upload.read(64.kilobytes).to_s, allowed: PhotoIntake::ImagePreparer::ALLOWED_TYPES)
      nil
    rescue Media::InvalidImageError
      NOT_AN_IMAGE
    end

    def render_new_error(message)
      @error = message
      render :new, status: :unprocessable_entity
    end
  end
end
