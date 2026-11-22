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

      user = user_signed_in? ? link_current_user(auth) : find_or_build_user(auth)
      unless user
        session.delete(:return_to)
        redirect_to root_path, alert: "Account mismatch"
        return
      end

      user.name ||= auth.info.name
      user.save!
      store_google_tokens!(user, auth)

      sign_in_and_redirect user, event: :authentication
    rescue StandardError => e
      Rails.logger.error("Google sign-in failed: #{e.class}")
      Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
      redirect_to root_path, alert: "Google sign-in failed"
    end

    def failure
      # Signed-in users only reach Google through the calendar connect, so send them back to the week plan.
      redirect_to user_signed_in? ? week_plan_path : root_path, alert: "Google sign-in was cancelled"
    end

    private

    def find_or_build_user(auth)
      user = User.from_omniauth(auth)
      existing = User.where("lower(email) = ?", auth.info.email.downcase).where(provider: nil).first
      if user.new_record? && existing
        user = existing
        user.provider = auth.provider
        user.uid = auth.uid
      end
      user
    end

    # 6.1 calendar connect: a signed-in user links the Google account to themselves, whatever its email.
    # Returns nil when that Google account already belongs to someone else.
    def link_current_user(auth)
      owner = User.find_by(provider: auth.provider, uid: auth.uid)
      return nil if owner && owner.id != current_user.id

      current_user.provider = auth.provider
      current_user.uid = auth.uid
      current_user
    end

    def store_google_tokens!(user, auth)
      creds = auth.credentials
      user.google_access_token = creds.token
      user.google_refresh_token = creds.refresh_token if creds.refresh_token.present?
      user.google_token_expires_at = Time.zone.at(creds.expires_at) if creds.expires_at
      user.save!
    end

    def after_sign_in_path_for(resource)
      session.delete(:return_to) || calendar_connect_origin || super
    end

    # OmniAuth keeps the request's origin param (the week plan's Connect button sends /week_plan?sync=1).
    # Only week plan paths are followed, so the param cannot become an open redirect.
    def calendar_connect_origin
      origin = request.env["omniauth.origin"].to_s
      path = URI.parse(origin).then { |uri| uri.host.nil? && uri.scheme.nil? ? uri.path : nil }
      origin if path == week_plan_path
    rescue URI::InvalidURIError
      nil
    end
  end
end
