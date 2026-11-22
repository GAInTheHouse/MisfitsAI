# frozen_string_literal: true

module OutfitPreviewsHelper
  def outfit_preview_avatar_ready?(rec)
    profile = rec.week_plan.user.profile
    profile.avatar_status == "ready" && profile.avatar.attached?
  end
end