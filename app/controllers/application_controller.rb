# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern unless Rails.env.test?

  before_action :authenticate_user!
  before_action :require_onboarding!

  rescue_from ApplicationError, with: :handle_application_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  helper_method :current_nav

  def current_nav
    @current_nav ||= begin
      path = request.path
      return :wardrobe if path.start_with?("/wardrobe", "/garments")
      return :calendar if path.start_with?("/week_plan", "/calendar_sync")
      return :outfits if path.start_with?("/outfits", "/outfit_previews", "/weather")
      return :profile if path.start_with?("/profile", "/onboarding", "/measurements", "/avatar")

      nil
    end
  end

  protected

  def after_sign_in_path_for(resource)
    if Feature.enabled?(:onboarding) && resource.onboarding_completed_at.nil?
      onboarding_path
    else
      wardrobe_path
    end
  end

  def require_onboarding!
    return unless Feature.enabled?(:onboarding)
    return if devise_controller?
    return if is_a?(PagesController)
    return if is_a?(Admin::BaseController)
    return if is_a?(Api::BaseController)
    return if controller_path.start_with?("onboarding/")
    return if controller_path == "profiles" || controller_path == "measurements"
    return unless current_user
    return if current_user.onboarding_completed_at.present?

    redirect_to onboarding_path
  end

  def handle_application_error(error)
    flash.now[:alert] = error.user_message
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: error.user_message) }
      # update, not replace: shared/flash has no #flash wrapper, so replace would remove the container.
      format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "shared/flash") }
      format.json { render json: { error: error.user_message }, status: :unprocessable_entity }
    end
  end

  def handle_not_found(_error)
    respond_to do |format|
      format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
      format.json { head :not_found }
      format.any { head :not_found }
    end
  end
end
