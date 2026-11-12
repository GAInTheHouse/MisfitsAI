# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Calendar connect and week plan", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :onboarded) }

  before { sign_in user }

  describe "POST /calendar_sync" do
    it "sends a user without tokens to Google with a 307 and returns to the week plan with sync=1" do
      post calendar_sync_path
      expect(response).to have_http_status(:temporary_redirect)
      expect(response).to redirect_to(user_google_oauth2_omniauth_authorize_path)
      expect(session[:return_to]).to eq(week_plan_path(sync: 1))
    end

    it "queues a sync for a connected user" do
      user.update!(google_refresh_token: "refresh")
      expect { post calendar_sync_path }.to have_enqueued_job(Planner::SyncCalendarJob).with(user.id)
      expect(response).to redirect_to(week_plan_path)
    end
  end

  describe "GET /week_plan?sync=1" do
    it "queues one sync after OAuth and drops the param" do
      user.update!(google_refresh_token: "refresh")
      expect { get week_plan_path(sync: 1) }.to have_enqueued_job(Planner::SyncCalendarJob).with(user.id)
      expect(response).to redirect_to(week_plan_path)
    end

    it "does not queue a sync when the connect did not produce tokens" do
      expect { get week_plan_path(sync: 1) }.not_to have_enqueued_job(Planner::SyncCalendarJob)
      expect(response).to redirect_to(week_plan_path)
    end
  end

  describe "GET /week_plan" do
    it "asks a previously connected user to reconnect once the tokens are gone" do
      user.update!(google_calendar_connected_at: 1.day.ago, google_refresh_token: nil)
      get week_plan_path
      expect(response.body).to include(Planner::CalendarSync::RECONNECT_MESSAGE)
    end

    it "shows no reconnect prompt to a user who never connected" do
      get week_plan_path
      expect(response.body).not_to include(Planner::CalendarSync::RECONNECT_MESSAGE)
    end
  end

  describe "POST /week_plan/generate without enough garments" do
    it "renders the guard with a link to the wardrobe" do
      post generate_week_plan_path
      expect(response).to have_http_status(:unprocessable_entity)
      html = Nokogiri::HTML(response.body)
      expect(html.text).to include("Add at least one top and one bottom (or a dress) first.")
      link = html.css("a").find { _1.text == "Go to your wardrobe" }
      expect(link&.[]("href")).to eq(wardrobe_path)
    end
  end

  describe "Google callback while signed in (calendar connect)" do
    around do |example|
      test_mode = OmniAuth.config.test_mode
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "connect-uid",
        info: { email: "different.address@gmail.com", name: "Someone" },
        credentials: { token: "access", refresh_token: "refresh", expires_at: 1.hour.from_now.to_i }
      )
      example.run
    ensure
      OmniAuth.config.mock_auth[:google_oauth2] = nil
      OmniAuth.config.test_mode = test_mode
    end

    it "links the Google account to the signed-in user, keeps their email, and returns to the week plan" do
      post calendar_sync_path
      expect do
        get user_google_oauth2_omniauth_callback_path,
            env: { "omniauth.auth" => OmniAuth.config.mock_auth[:google_oauth2] }
      end.not_to change(User, :count)

      expect(response).to redirect_to(week_plan_path(sync: 1))
      expect(user.reload).to have_attributes(uid: "connect-uid", google_refresh_token: "refresh")
      expect(user.email).not_to eq("different.address@gmail.com")
    end

    it "refuses a Google account that already belongs to another user" do
      other = create(:user, provider: "google_oauth2", uid: "connect-uid")
      get user_google_oauth2_omniauth_callback_path,
          env: { "omniauth.auth" => OmniAuth.config.mock_auth[:google_oauth2] }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Account mismatch")
      expect(user.reload.uid).to be_nil
      expect(other.reload.google_refresh_token).not_to eq("refresh")
    end
  end
end
