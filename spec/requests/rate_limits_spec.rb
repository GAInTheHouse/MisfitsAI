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

  it "limits adding results to 30 a minute per user" do
    30.times { select_result }
    select_result
    expect(response).to have_http_status(:too_many_requests)
  end
end
