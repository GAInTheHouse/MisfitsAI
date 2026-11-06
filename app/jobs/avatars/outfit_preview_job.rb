# frozen_string_literal: true

module Avatars
  class OutfitPreviewJob < ApplicationJob
    queue_as :ai_images

    rescue_from(StandardError) do |e|
      rec = OutfitRecommendation.find_by(id: arguments.first)
      rec&.update!(preview_status: "failed")
      raise e
    end

    def perform(rec_id)
      rec     = OutfitRecommendation.find(rec_id)
      profile = rec.week_plan.user.profile
      user    = rec.week_plan.user

      avatar_check = profile.avatar.attached? ? profile.avatar.blob.checksum : "none"
      cache_key    = Digest::SHA256.hexdigest([ avatar_check, *rec.garments_in_display_order.map(&:id) ].join(":"))

      if rec.preview_status == "ready" && rec.preview_cache_key == cache_key
        broadcast_preview(rec, user)
        return
      end

      outfit_desc = build_outfit_desc(rec)
      jpeg        = nil
      strategy    = nil

      unless ai_disabled_or_quota_exceeded?(user)
        jpeg, strategy = try_imagen_subject(rec, profile, user, outfit_desc)
        jpeg, strategy = try_gemini_image(rec, profile, user, outfit_desc) unless jpeg
      end

      unless jpeg
        avatar_bytes = profile.avatar.attached? ? profile.avatar.download : nil
        jpeg = Avatars::OutfitCollage.build(avatar_bytes, rec.garments_in_display_order)
        strategy = "collage"
      end

      rec.preview_image.attach(io: StringIO.new(jpeg), filename: "preview.jpg", content_type: "image/jpeg")
      rec.update!(preview_status: "ready", preview_strategy: strategy, preview_cache_key: cache_key)
      broadcast_preview(rec, user)
    end

    private

    def build_outfit_desc(rec)
      items = rec.garments_in_display_order
      return "a complete outfit" if items.empty?

      items.map { |g| "#{g.name} (#{g.category})" }.join(", ")
    end

    def ai_disabled_or_quota_exceeded?(user)
      !ActiveModel::Type::Boolean.new.cast(ENV.fetch("AI_IMAGE_GEN_ENABLED", "true"))
    rescue StandardError
      false
    end

    def try_imagen_subject(rec, profile, user, outfit_desc)
      return [ nil, nil ] unless profile.avatar.attached?

      avatar_jpeg   = profile.avatar.download
      avatar_image  = Ai::Image.new(bytes: avatar_jpeg, mime_type: "image/jpeg")
      prompt        = Avatars::Prompts.outfit_subject(outfit_desc: outfit_desc)
      result        = Ai::Client.current.generate_image_with_subject(
        kind: :outfit_preview_subject, prompt: prompt, subject: avatar_image, aspect_ratio: "9:16", user: user
      )
      jpeg = Media::ImageNormalizer.to_jpeg(result.bytes)
      [ jpeg, "imagen_subject" ]
    rescue Ai::Error, StandardError
      [ nil, nil ]
    end

    def try_gemini_image(rec, profile, user, outfit_desc)
      return [ nil, nil ] unless profile.avatar.attached?

      avatar_jpeg    = profile.avatar.download
      avatar_img     = Ai::Image.new(bytes: avatar_jpeg, mime_type: "image/jpeg")
      garment_images = rec.garments_in_display_order.filter_map do |g|
        next unless g.image.attached?

        Ai::Image.new(bytes: g.image.download, mime_type: "image/jpeg")
      end

      images = [ avatar_img, *garment_images ]
      prompt = Avatars::Prompts.outfit_gemini(outfit_desc: outfit_desc, n_garment_images: garment_images.size)
      result = Ai::Client.current.generate_image_multimodal(
        kind: :outfit_preview_gemini, prompt: prompt, images: images, user: user
      )
      jpeg = Media::ImageNormalizer.to_jpeg(result.bytes)
      [ jpeg, "gemini_image" ]
    rescue Ai::Error, StandardError
      [ nil, nil ]
    end

    def broadcast_preview(rec, user)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ user, :planner ],
        target: "on_me_#{rec.id}",
        partial: "outfit_previews/preview",
        locals: { rec: rec }
      )
    end
  end
end
