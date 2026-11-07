# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: :google_oauth2

    def google_oauth2
      auth = request.env["omniauth.auth"]
      if auth.nil?
        redirect_to root_path, alert: "Google sign-in was cancelled"
        return
      end

      user = User.from_omniauth(auth)
      existing = User.where("lower(email) = ?", auth.info.email.downcase).where(provider: nil).first
      if user.new_record? && existing
        user = existing
        user.provider = auth.provider
        user.uid = auth.uid
      end

      user.name ||= auth.info.name
      user.save!
      store_google_tokens!(user, auth)

      if user_signed_in? && current_user.id != user.id
        redirect_to root_path, alert: "Account mismatch"
        return
      end

      sign_in_and_redirect user, event: :authentication
    rescue StandardError => e
      Rails.logger.error("Google sign-in failed: #{e.class}")
      Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
      redirect_to root_path, alert: "Google sign-in failed"
    end 

    def failure
      redirect_to root_path, alert: "Google sign-in was cancelled"
    end

    private

    def store_google_tokens!(user, auth)
      creds = auth.credentials
      user.google_access_token = creds.token
      user.google_refresh_token = creds.refresh_token if creds.refresh_token.present?
      user.google_token_expires_at = Time.zone.at(creds.expires_at) if creds.expires_at
      user.save!
    end

    def after_sign_in_path_for(resource)
      session.delete(:return_to) || super
    end
  end
end
