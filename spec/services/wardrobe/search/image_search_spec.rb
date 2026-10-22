# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::Search::ImageSearch do
  include ActiveSupport::Testing::TimeHelpers

  let(:endpoint) { %r{\Ahttps://serpapi\.com/search\.json} }
  let(:api_key) { "sk-test-SECRET-KEY" }
  let(:white_shirt) { File.read(Rails.root.join("spec/fixtures/serpapi/white_shirt.json")) }

  around { |example| with_env("SERPAPI_KEY" => api_key) { example.run } }

  def stub_page(body, ijn: nil, status: 200)
    query = { "engine" => "google_images" }
    query["ijn"] = ijn.to_s if ijn
    stub_request(:get, endpoint).with(query: hash_including(query))
                                .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  def results_json(count, noun: "shirt")
    { images_results: Array.new(count) { |i| { title: "White #{noun} #{i}", link: "https://shop.example.com/#{i}",
                                               original: "https://img.example.com/#{i}.jpg" } } }.to_json
  end

  def search(**args)
    described_class.call(query: "Uniqlo white shirt", **args)
  end

  describe "query (design doc 6.5 step 3)" do
    it "joins the parts in the documented order" do
      q = described_class.new(query: "Uniqlo  white shirt", color: "White", material: "Cotton", kind: "Oxford shirt",
                              gender: "men", limit: 8).q
      expect(q).to eq("Uniqlo white shirt for men White Cotton Oxford shirt " \
                      "clothing product photo, studio, on white background -person -people -model -man -woman -face -selfie")
    end

    it "leaves out blank parts and any gender other than men or women" do
      q = described_class.new(query: "Zara", color: "", material: nil, kind: nil, gender: "any", limit: 8).q
      expect(q).to eq("Zara clothing product photo, studio, on white background -person -people -model -man -woman -face -selfie")
    end

    it "asks SerpAPI's google_images engine with the key and the clamped limit" do
      request = stub_page(results_json(20)).with(query: hash_including("api_key" => api_key, "num" => "20"))
      search(limit: 50)
      expect(request).to have_been_requested.once
    end
  end

  describe "results" do
    it "returns ranked, deduplicated web images as image_url / thumbnail_url / title / source_url" do
      stub_page(white_shirt)
      stub_page({ images_results: [] }.to_json, ijn: 1)

      results = search(color: "White")

      # The linen result ranks first: it also earns apparel-hint points ("regular", "fit", "cotton").
      expect(results.first[:title]).to eq("Uniqlo Linen Blend Shirt White, regular fit cotton")
      oxford = results.find { _1[:image_url] == "https://image.uniqlo.com/oxford-white.jpg" }
      expect(oxford).to eq(
        image_url: "https://image.uniqlo.com/oxford-white.jpg",
        thumbnail_url: "https://encrypted-tbn0.gstatic.com/images?q=tbn:oxford",
        title: "Uniqlo Men's Oxford Shirt - White",
        source_url: "https://www.uniqlo.com/us/en/products/oxford-shirt"
      )
      titles = results.map { _1[:title] }
      expect(titles).not_to include("White Laptop Stand", "Inline preview", "No image at all")
      expect(results.map { _1[:image_url] }).to all(start_with("https://"))
      expect(results.map { _1[:image_url] }.uniq.size).to eq(results.size)
    end

    it "treats SerpAPI's \"no results\" answer as an empty list" do
      stub_page(File.read(Rails.root.join("spec/fixtures/serpapi/no_results.json")))
      expect(search).to eq([])
    end
  end

  describe "thumbnail and link safety" do
    def one(result)
      stub_page({ images_results: [ { "title" => "White shirt", "link" => "https://shop.example.com/p",
                                      "original" => "https://img.example.com/1.jpg" }.merge(result) ] }.to_json)
      search.first
    end

    it "keeps a thumbnail from an allowed host" do
      expect(one("thumbnail" => "https://encrypted-tbn1.gstatic.com/images?q=tbn:1")[:thumbnail_url])
        .to eq("https://encrypted-tbn1.gstatic.com/images?q=tbn:1")
    end

    [
      "https://evil.example.com/pixel.gif", "http://encrypted-tbn0.gstatic.com/images?q=1",
      "https://tracker.gstatic.com.evil.example/x.jpg", "javascript:alert(1)", "data:image/gif;base64,R0lGOD",
      "https://user:pw@encrypted-tbn0.gstatic.com/x"
    ].each do |thumbnail|
      it "gives no preview for the thumbnail #{thumbnail.inspect}" do
        expect(one("thumbnail" => thumbnail)[:thumbnail_url]).to be_nil
      end
    end

    it "drops links that carry an api_key parameter or the key itself" do
      result = one("link" => "https://serpapi.com/search.json?engine=google&api_key=other",
                   "original" => "https://img.example.com/1.jpg?k=#{api_key}",
                   "thumbnail" => "https://encrypted-tbn0.gstatic.com/images?q=1")
      expect(result[:source_url]).to be_nil
      expect(result[:image_url]).to eq("https://encrypted-tbn0.gstatic.com/images?q=1") # falls back to the thumbnail
      expect(result.values.join).not_to include(api_key, "api_key")
    end
  end

  describe "backfill from page 2 (design doc 6.5 step 7)" do
    # threshold = min(limit, max(2, (limit + 1) / 2)): 1 -> 1, 2 -> 2, 8 -> 4, 20 -> 10
    { 1 => 1, 2 => 2, 8 => 4, 20 => 10 }.each do |limit, threshold|
      it "with limit #{limit}, fetches page 2 when page 1 gives fewer than #{threshold} results" do
        stub_page(results_json(threshold - 1))
        page_two = stub_page(results_json(limit, noun: "tee"), ijn: 1)
        search(limit: limit)
        expect(page_two).to have_been_requested.once
      end

      it "with limit #{limit}, does not fetch page 2 when page 1 gives #{threshold} results" do
        stub_page(results_json(threshold))
        page_two = stub_page(results_json(limit), ijn: 1)
        search(limit: limit)
        expect(page_two).not_to have_been_requested
      end
    end

    it "merges page 2 results in" do
      stub_page(results_json(1))
      stub_page({ images_results: [ { title: "White shirt extra", original: "https://img.example.com/x.jpg" } ] }.to_json, ijn: 1)
      expect(search.map { _1[:title] }).to include("White shirt 0", "White shirt extra")
    end

    it "keeps the page 1 results when page 2 fails" do
      stub_page(results_json(1))
      stub_page("{}", ijn: 1, status: 500)
      expect(search.map { _1[:title] }).to eq([ "White shirt 0" ])
    end
  end

  describe "errors (design doc 6.5 step 9)" do
    def error_for
      yield
      nil
    rescue Wardrobe::Search::Error => e
      e
    end

    it "requires a brand or keywords, without calling SerpAPI" do
      error = error_for { described_class.call(query: "   ") }
      expect([ error.user_message, error.status ]).to eq([ "Enter a brand or keywords", :unprocessable_entity ])
      expect(a_request(:any, endpoint)).not_to have_been_made
    end

    it "reports a missing SERPAPI_KEY as not configured" do
      error = with_env("SERPAPI_KEY" => nil) { error_for { search } }
      expect([ error.user_message, error.status ]).to eq([ "Garment search is not configured", :service_unavailable ])
    end

    [ 400, 401, 429, 500, 503 ].each do |status|
      it "reports HTTP #{status} as a provider failure" do
        stub_page("{}", status: status)
        error = error_for { search }
        expect([ error.user_message, error.status ]).to eq([ "Garment search provider failed. Try again later.", :bad_gateway ])
      end
    end

    it "reports a timeout as a failed request" do
      stub_request(:get, endpoint).to_timeout
      error = error_for { search }
      expect([ error.user_message, error.status ]).to eq([ "Garment search request failed. Please retry.", :gateway_timeout ])
    end

    it "reports a connection failure as a failed request" do
      stub_request(:get, endpoint).to_raise(Faraday::ConnectionFailed.new("connection refused"))
      expect(error_for { search }.user_message).to eq("Garment search request failed. Please retry.")
    end

    it "reports invalid JSON and SerpAPI error answers as provider failures" do
      stub_page("<html>oops</html>")
      expect(error_for { search }.user_message).to eq("Garment search provider failed. Try again later.")

      stub_page({ error: "Invalid API key." }.to_json)
      expect(error_for { search }.user_message).to eq("Garment search provider failed. Try again later.")
    end
  end

  describe "caching (design doc 11.5)" do
    it "serves a repeated search from the cache for 24 hours" do
      request = stub_page(results_json(8))
      2.times { search }
      expect(request).to have_been_requested.once

      travel 25.hours do
        search
        expect(request).to have_been_requested.twice
      end
    end

    it "does not cache errors" do
      stub_page("{}", status: 500)
      expect { search }.to raise_error(Wardrobe::Search::Error)
      stub_page(results_json(8))
      expect(search.size).to eq(8)
    end
  end

  describe "API key handling" do
    it "keeps the key out of errors, logs, cache keys and results" do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)
      cache_keys = []
      allow(Rails.cache).to receive(:fetch).and_wrap_original { |m, key, **opts, &blk| cache_keys << key.to_s; m.call(key, **opts, &blk) }

      stub_page("{}", status: 500)
      error = (search rescue $!)
      stub_request(:get, endpoint).to_timeout
      timeout = (described_class.call(query: "other") rescue $!)
      stub_page(results_json(8))
      results = described_class.call(query: "third")

      text = [ error.message, error.user_message, timeout.message, timeout.user_message, log.string, cache_keys.join, results.to_s ].join
      expect(text).not_to include(api_key)
    ensure
      Rails.logger = original_logger
    end
  end
end
