# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Login rate limits", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { Rack::Attack.reset! }

  it "throttles the sixth sign-in attempt in 20 seconds" do
    5.times do
      post user_session_path, params: { user: { email: "brute@example.com", password: "wrong" } }
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post user_session_path, params: { user: { email: "brute@example.com", password: "wrong" } }
    expect(response).to have_http_status(:too_many_requests)
  end
end
