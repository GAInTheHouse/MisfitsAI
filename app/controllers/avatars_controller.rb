# frozen_string_literal: true

class AvatarsController < ApplicationController
  include IntakeUpload

  ALLOWED_TYPES = %w[image/jpeg image/png image/webp image/heic].freeze
  MAX_SIZE = 15.megabytes

  def show
    @profile = current_user.profile
    render partial: "avatars/avatar_section", locals: { profile: @profile } if turbo_frame_request?
  end

  def create
    file = params[:selfie]

    if file.blank?
      return redirect_to profile_path, alert: "Uploaded file is empty"
    end

    if file.size > MAX_SIZE
      return redirect_to profile_path, alert: "Image too large"
    end

    begin
      Media::ImageNormalizer.sniff!(file.read(64.kilobytes))
      file.rewind
    rescue Media::InvalidImageError
      return redirect_to profile_path, alert: "Please upload a JPEG, PNG, WebP or HEIC image"
    end

    profile = current_user.profile
    profile.pending_selfie.attach(file)
    profile.update!(avatar_status: "pending")
    Avatars::GenerateAvatarJob.perform_later(profile.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("avatar_section",
                                                  partial: "avatars/avatar_section",
                                                  locals: { profile: profile })
      end
      format.html { redirect_to profile_path, notice: "Generating your avatar…" }
    end
  end
end
