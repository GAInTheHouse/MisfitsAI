# frozen_string_literal: true

class AvatarsController < ApplicationController
  include IntakeUpload

  def show
    @profile = current_user.profile
    if turbo_frame_request?
      render partial: "avatars/profile_avatar_frame", locals: { profile: @profile }
    end
  end

  def create
    file = params[:selfie]
    result = Avatars::SelfieUpload.accept(file)
    unless result.ok
      return redirect_to profile_path, alert: result.error
    end

    profile = current_user.profile
    Avatars::SelfieUpload.enqueue!(profile, file)

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