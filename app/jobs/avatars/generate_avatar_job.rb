# frozen_string_literal: true

module Avatars
  class GenerateAvatarJob < ApplicationJob
    queue_as :ai_images

    rescue_from(StandardError) do |_e|
      profile = UserProfile.find_by(id: arguments.first)
      if profile && profile.avatar_status != "ready"
        profile.update!(avatar_status: "failed", avatar_error: "Avatar generation failed. Please try another photo.")
        broadcast_avatar(profile)
      end
    end

    def perform(profile_id)
      profile = UserProfile.find(profile_id)
      if profile.avatar_status == "ready" && profile.avatar.attached?
        broadcast_avatar(profile)
        return
      end

      user = profile.user
      context = Profiles.for(user)

      description = nil
      begin
        selfie_bytes = profile.pending_selfie.download
        selfie_jpeg  = Media::ImageNormalizer.to_jpeg(selfie_bytes)
        selfie_image = Ai::Image.new(bytes: selfie_jpeg, mime_type: "image/jpeg")
        description  = Ai::Client.current.generate_text(
          kind: :selfie_description,
          prompt: Avatars::Prompts::SELFIE,
          images: [ selfie_image ],
          temperature: 0.25,
          max_output_tokens: 4096,
          user: user
        )
      rescue StandardError => e
        Rails.logger.warn("[Avatars::GenerateAvatarJob] selfie description failed: #{e.class}, continuing without it")
      end

      prompt = Avatars::PromptBuilder.portrait(description: description, context: context)
      result = Ai::Client.current.generate_image(kind: :avatar_portrait, prompt: prompt, aspect_ratio: "1:1", user: user)
      jpeg   = Media::ImageNormalizer.to_square_jpeg(result.bytes, size: 512)

      profile.avatar.attach(io: StringIO.new(jpeg), filename: "avatar.jpg", content_type: "image/jpeg")
      profile.update!(avatar_status: "ready", avatar_error: nil)
      broadcast_avatar(profile)
    ensure
      purge_selfie(profile)
    end

    private

    def broadcast_avatar(profile)
      user = profile.user
      Turbo::StreamsChannel.broadcast_replace_to(
        [ user, :avatar ],
        target: "avatar_section",
        partial: "avatars/avatar_section",
        locals: { profile: profile }
      )

      plan = user.week_plans.order(created_at: :desc).first
      return unless plan

      plan.outfit_recommendations.includes(:week_plan, :top, :bottom, :dress, :outerwear, :shoes).find_each do |rec|
        Turbo::StreamsChannel.broadcast_replace_to(
          [ user, :planner ],
          target: ActionView::RecordIdentifier.dom_id(rec),
          partial: "outfits/day_card",
          locals: { rec: rec }
        )
      end
    end

    def purge_selfie(profile)
      return unless profile&.pending_selfie&.attached?

      profile.pending_selfie.purge
    rescue StandardError => e
      Rails.logger.warn("[Avatars::GenerateAvatarJob] selfie purge failed: #{e.class}")
    end
  end
end
