# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wardrobe searches", type: :request do
  let(:user) { create(:user, :onboarded) }
  let(:api_key) { "sk-test-SECRET-KEY" }
  let(:endpoint) { %r{\Ahttps://serpapi\.com/search\.json} }
  let(:turbo_stream) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:frame) { { "Turbo-Frame" => "garment_search_results" } }
  let(:results) do
    { images_results: [
      { title: "Uniqlo Oxford Shirt White", link: "https://shop.example.com/oxford",
        original: "https://images.example.com/oxford.jpg", thumbnail: "https://encrypted-tbn0.gstatic.com/images?q=1" }
    ] }.to_json
  end

  around { |example| with_env("SERPAPI_KEY" => api_key) { example.run } }

  before do
    sign_in user
    stub_request(:get, endpoint).to_return(status: 200, body: results, headers: { "Content-Type" => "application/json" })
  end

  it "GET /wardrobe/searches/new shows the search form" do
    get new_wardrobe_search_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="garment_search_form"', 'turbo-frame id="garment_search_results"')
  end

  it "the wardrobe page's Search tab holds the same form" do
    get wardrobe_path
    expect(response.body).to include('id="garment_search_form"', "Any kind", "Oxford shirt")
  end

  describe "POST /wardrobe/searches" do
    it "renders the results inside the results frame" do
      post wardrobe_searches_path, params: { search: { brand: "Uniqlo", keywords: "white shirt" } }, headers: frame
      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML5(response.body)
      expect(doc.css("turbo-frame#garment_search_results article.search-result").size).to eq(1)
      expect(response.body).to include("https://encrypted-tbn0.gstatic.com/images?q=1", 'referrerpolicy="no-referrer"')
    end

    it "sends the brand and keywords as the base query" do
      post wardrobe_searches_path, params: { search: { brand: "Uniqlo", keywords: "white shirt", color: "White" } }
      # One result is below the backfill threshold, so page 2 is requested too.
      expect(a_request(:get, endpoint).with(query: hash_including("q" => /\AUniqlo white shirt White /)))
        .to have_been_made.at_least_once
    end

    it "escapes provider text, so a title cannot inject HTML or script" do
      evil = { images_results: [ { title: %(Shirt"><script>alert(1)</script><img src=x onerror=alert(2)>),
                                   link: "https://shop.example.com/x", original: "https://images.example.com/x.jpg",
                                   thumbnail: "https://encrypted-tbn0.gstatic.com/images?q=x" } ] }.to_json
      stub_request(:get, endpoint).to_return(status: 200, body: evil, headers: { "Content-Type" => "application/json" })

      post wardrobe_searches_path, params: { search: { keywords: "shirt" } }

      doc = Nokogiri::HTML5(response.body)
      expect(doc.css("script").map(&:text).join).not_to include("alert(1)")
      expect(doc.css("img[onerror]")).to be_empty
      expect(doc.at_css("article.search-result")["data-title"]).to start_with(%(Shirt"><script>))
    end

    it "only renders thumbnails from hosts the CSP allows" do
      mixed = { images_results: [
        { title: "Shirt A", original: "https://images.example.com/a.jpg", thumbnail: "https://evil.example.com/a.gif" },
        { title: "Shirt B", original: "https://images.example.com/b.jpg", thumbnail: "https://encrypted-tbn2.gstatic.com/images?q=b" }
      ] }.to_json
      stub_request(:get, endpoint).to_return(status: 200, body: mixed, headers: { "Content-Type" => "application/json" })

      post wardrobe_searches_path, params: { search: { keywords: "shirt" } }

      srcs = Nokogiri::HTML5(response.body).css("article.search-result img").map { _1["src"] }
      expect(srcs).to eq([ "https://encrypted-tbn2.gstatic.com/images?q=b" ])
      expect(response.body).not_to include("evil.example.com")
      expect(response.body).to include("No preview")
    end

    it "sends a CSP that allows exactly the configured thumbnail hosts" do
      post wardrobe_searches_path, params: { search: { keywords: "shirt" } }
      img_src = response.headers["Content-Security-Policy"][/img-src [^;]*/]
      Rails.configuration.x.search_thumbnail_hosts.each { expect(img_src).to include("https://#{_1}") }
      expect(img_src).not_to include("*.gstatic.com")
      expect(img_src).not_to match(%r{https?://\*(?!\.googleusercontent)})
    end

    it "never puts the API key in the page" do
      post wardrobe_searches_path, params: { search: { keywords: "white shirt" } }
      expect(response.body).not_to include(api_key)
    end

    it "shows a missing brand/keywords error in the frame with 422" do
      post wardrobe_searches_path, params: { search: { brand: "", keywords: "" } }, headers: frame
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Enter a brand or keywords")
    end

    it "shows provider failures with 502" do
      stub_request(:get, endpoint).to_return(status: 500)
      post wardrobe_searches_path, params: { search: { keywords: "white shirt" } }, headers: frame
      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to include("Garment search provider failed. Try again later.")
    end

    it "shows timeouts with 504" do
      stub_request(:get, endpoint).to_timeout
      post wardrobe_searches_path, params: { search: { keywords: "white shirt" } }, headers: frame
      expect(response).to have_http_status(:gateway_timeout)
      expect(response.body).to include("Garment search request failed. Please retry.")
    end

    it "shows a missing key as not configured with 503" do
      with_env("SERPAPI_KEY" => nil) { post wardrobe_searches_path, params: { search: { keywords: "shirt" } }, headers: frame }
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Garment search is not configured")
    end
  end

  describe "POST /wardrobe/searches/select" do
    let(:pick) do
      { image_url: "https://images.example.com/oxford.jpg", title: "Uniqlo Oxford Shirt White",
        source_url: "https://shop.example.com/oxford", search: { category: "top", brand: "Uniqlo", keywords: "white shirt" } }
    end

    it "adds the garment for the signed-in user and queues the image import" do
      expect { post select_wardrobe_searches_path, params: pick }
        .to change(user.garments, :count).by(1)
        .and have_enqueued_job(Wardrobe::ImportRemoteImageJob)
      expect(response).to redirect_to(wardrobe_path)
      expect(user.garments.last).to have_attributes(source: "search", image_status: "pending", name: "Uniqlo Oxford Shirt White")
    end

    it "cannot add the garment to another user's wardrobe" do
      other = create(:user)
      post select_wardrobe_searches_path, params: pick.merge(user_id: other.id, search: pick[:search].merge(user_id: other.id))
      expect(other.garments).to be_empty
      expect(user.garments.count).to eq(1)
    end

    it "prepends the card with a Turbo Stream response" do
      post select_wardrobe_searches_path, params: pick, headers: turbo_stream
      expect(response.body).to include('action="prepend" target="garments"', "Added Uniqlo Oxford Shirt White to your wardrobe.")
    end

    it "refuses an unusable image link without saving" do
      expect { post select_wardrobe_searches_path, params: pick.merge(image_url: "javascript:alert(1)"), headers: turbo_stream }
        .not_to change(Garment, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("That image can&#39;t be used. Pick another result.")
    end

    it "explains when no category can be worked out" do
      post select_wardrobe_searches_path, params: pick.merge(title: "Mystery Item", search: { keywords: "mystery" })
      expect(response).to redirect_to(wardrobe_path)
      expect(flash[:alert]).to eq("Category can't be blank")
    end
  end
end
