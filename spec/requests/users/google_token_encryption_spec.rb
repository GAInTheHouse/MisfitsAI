# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Google OAuth token storage", type: :request do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "encrypt-uid",
      info: { email: "secure@example.com", name: "Secure User" },
      credentials: { token: "access-token", refresh_token: "refresh-token", expires_at: 1.hour.from_now.to_i }
    )
  end

  it "stores Google tokens encrypted at rest" do
    get user_google_oauth2_omniauth_callback_path

    user = User.find_by!(email: "secure@example.com")
    raw = User.connection.select_value("SELECT google_access_token FROM users WHERE id = '#{user.id}'")
    expect(raw).not_to eq("access-token")
    expect(user.google_access_token).to eq("access-token")
    expect(user.google_refresh_token).to eq("refresh-token")
  end
end
