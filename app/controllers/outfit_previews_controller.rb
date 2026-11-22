# frozen_string_literal: true

class OutfitPreviewsController < ApplicationController
  before_action :find_recommendation

  def show
    if turbo_frame_request?
      render partial: "outfit_previews/on_me_frame", locals: { rec: @rec }
    else
      render partial: "outfit_previews/preview", locals: { rec: @rec }
    end
  end

  def create
    profile = current_user.profile
    unless avatar_ready?(profile)
      return respond_on_me
    end

    avatar_check = profile.avatar.attached? ? profile.avatar.blob.checksum : "none"
    cache_key    = Digest::SHA256.hexdigest(
      [ avatar_check, *@rec.garments_in_display_order.map(&:id) ].join(":")
    )

    if @rec.preview_status == "ready" && @rec.preview_cache_key == cache_key
      return respond_on_me
    end

    @rec.update!(preview_status: "pending")
    Avatars::OutfitPreviewJob.perform_later(@rec.id)
    respond_on_me
  end

  private

  def find_recommendation
    week_plan = current_user.week_plans.joins(:outfit_recommendations)
                            .where(outfit_recommendations: { id: params[:outfit_id] })
                            .first
    @rec = week_plan&.outfit_recommendations&.find_by(id: params[:outfit_id])
    head :not_found unless @rec
  end

  def avatar_ready?(profile)
    profile.avatar_status == "ready" && profile.avatar.attached?
  end

  def respond_on_me
    @rec.reload
    if turbo_frame_request?
      render partial: "outfit_previews/on_me_frame", locals: { rec: @rec }
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "on_me_#{@rec.id}",
            partial: "outfit_previews/preview",
            locals: { rec: @rec }
          )
        end
        format.html { redirect_to outfits_path }
      end
    end
  end
end
