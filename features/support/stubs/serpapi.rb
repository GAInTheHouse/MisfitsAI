# frozen_string_literal: true

# SerpAPI is always stubbed (design doc 8.2). Results use the google_images shape:
# { "title", "original", "thumbnail", "link" }.
module SerpapiStubs
  ENDPOINT = %r{\Ahttps://serpapi\.com/search\.json}

  def stub_serpapi(results:, page_two: [])
    ENV["SERPAPI_KEY"] ||= "test-serpapi-key"
    stub_request(:get, ENDPOINT).with(query: hash_including("engine" => "google_images"))
                                .to_return(serpapi_json(results))
    # Registered last so it wins for page 2 (ijn=1), which the backfill may request.
    stub_request(:get, ENDPOINT).with(query: hash_including("engine" => "google_images", "ijn" => "1"))
                                .to_return(serpapi_json(page_two))
  end

  def stub_serpapi_error(status: 500)
    ENV["SERPAPI_KEY"] ||= "test-serpapi-key"
    stub_request(:get, ENDPOINT).to_return(status: status, body: { error: "Upstream failure" }.to_json)
  end

  def stub_serpapi_timeout
    ENV["SERPAPI_KEY"] ||= "test-serpapi-key"
    stub_request(:get, ENDPOINT).to_timeout
  end

  private

  def serpapi_json(results)
    { status: 200, body: { images_results: results }.to_json, headers: { "Content-Type" => "application/json" } }
  end
end

World(SerpapiStubs)
