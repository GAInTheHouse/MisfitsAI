# frozen_string_literal: true

require "rails_helper"

# Rack::Attack limits for garment search (design doc 4.4).
RSpec.describe "Rate limits", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :onboarded) }
  let(:endpoint) { %r{\Ahttps://serpapi\.com/search\.json} }
  let(:pick) do
    { image_url: "https://images.example.com/oxford.jpg", title: "Oxford Shirt", search: { category: "top" } }
  end

  around { |example| with_env("SERPAPI_KEY" => "test-key") { example.run } }

  before do
    Rack::Attack.reset!
    sign_in user
    stub_request(:get, endpoint).to_return(status: 200, body: { images_results: [] }.to_json,
                                           headers: { "Content-Type" => "application/json" })
  end

  def search = post(wardrobe_searches_path, params: { search: { keywords: "shirt" } })
  def select_result = post(select_wardrobe_searches_path, params: pick)

  it "allows 10 searches a minute per user, then answers 429" do
    10.times do
      search
      expect(response).not_to have_http_status(:too_many_requests)
    end
    search
    expect(response).to have_http_status(:too_many_requests)
  end

  it "starts a new budget after a minute" do
    11.times { search }
    travel 61.seconds do
      search
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  it "keeps a separate budget per user" do
    11.times { search }
    sign_in create(:user, :onboarded)
    search
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "does not spend the search budget when adding results" do
    20.times { select_result }
    search
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "does not block adding results when the search budget is used up" do
    11.times { search }
    select_result
    expect(response).to redirect_to(wardrobe_path)
  end

  describe "hourly limit (G10, design doc 4.4: 60 per hour per user)" do
    # 10 requests a minute for six minutes stays under the per-minute limit and reaches 60 in the hour.
    def sixty_spread_over_six_minutes(start)
      6.times do |minute|
        travel_to(start + (minute * 61).seconds) do
          10.times do
            yield
            expect(response).not_to have_http_status(:too_many_requests)
          end
        end
      end
    end

    let(:start) { Time.zone.parse("2026-10-22 10:00") }

    it "allows 60 searches an hour per user, then answers 429 until the hour is over" do
      sixty_spread_over_six_minutes(start) { search }
      travel_to(start + 10.minutes) do
        search
        expect(response).to have_http_status(:too_many_requests)
      end
      travel_to(start + 61.minutes) do
        search
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    it "limits photo, receipt (and later avatar) posts to 60 an hour per user, separately from search" do
      paste = -> { post wardrobe_receipts_path, params: { receipt_text: "Linen shirt $30.00" } }
      sixty_spread_over_six_minutes(start) { paste.call }
      travel_to(start + 10.minutes) do
        paste.call
        expect(response).to have_http_status(:too_many_requests)
        search
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  it "limits adding results to 30 a minute per user" do
    30.times { select_result }
    select_result
    expect(response).to have_http_status(:too_many_requests)
  end
end
