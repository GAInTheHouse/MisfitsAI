# frozen_string_literal: true

module Avatars
  class SelfieUpload
    MAX_SIZE = 15.megabytes

    Result = Data.define(:ok, :error)

    def self.accept(file)
      if file.blank?
        return Result.new(ok: false, error: "Uploaded file is empty")
      end

      if file.size > MAX_SIZE
        return Result.new(ok: false, error: "Image too large")
      end

      begin
        Media::ImageNormalizer.sniff!(file.read(64.kilobytes))
        file.rewind
      rescue Media::InvalidImageError
        return Result.new(ok: false, error: "Please upload a JPEG, PNG, WebP or HEIC image")
      end

      Result.new(ok: true, error: nil)
    end

    def self.enqueue!(profile, file)
      profile.pending_selfie.attach(file)
      profile.update!(avatar_status: "pending")
      Avatars::GenerateAvatarJob.perform_later(profile.id)
    end
  end
end
