# frozen_string_literal: true

class ProfilesController < ApplicationController
  skip_before_action :require_onboarding!

  SECTIONS = %w[personal style sizes avatar_prefs].freeze

  def show
    @profile = current_user.profile
    @measurement = current_user.body_measurement || BodyMeasurement.new
  end

  def update
    @profile = current_user.profile
    section  = params[:section].to_s

    if SECTIONS.include?(section)
      update_profile_section(section)
    else
      redirect_to profile_path, alert: "Unknown section."
    end
  end

  private

  def update_profile_section(section)
    permitted = permitted_params_for(section)
    if @profile.update(permitted)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Saved"
          render turbo_stream: [
            turbo_stream.replace("profile_#{section}", partial: "profiles/#{section}", locals: { profile: @profile }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { redirect_to profile_path, notice: "Saved" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("profile_#{section}", partial: "profiles/#{section}", locals: { profile: @profile })
        end
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def permitted_params_for(section)
    case section
    when "personal"
      params.require(:user_profile).permit(:gender, :birthday)
    when "style"
      params.require(:user_profile).permit(:skin_tone, :color_tone, favorite_colors: [], avoided_colors: [])
    when "sizes"
      params.require(:user_profile).permit(:top_size, :bottom_size, :shoe_size)
    when "avatar_prefs"
      params.require(:user_profile).permit(:hair_style, :hair_color, :body_type)
    else
      {}
    end
  end
end
