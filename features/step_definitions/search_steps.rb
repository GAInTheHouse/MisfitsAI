# frozen_string_literal: true

# Phase 2 image-search steps (design doc 6.5, 8.3). SerpAPI and image hosts are always stubbed.

Given("the image search returns:") do |table|
  stub_serpapi(results: table.hashes)
end

Given("the image search provider returns an error") do
  stub_serpapi_error(status: 500)
end

Given("the image search times out") do
  stub_serpapi_timeout
end

Given("image search is not configured") do
  ENV.delete("SERPAPI_KEY") # restored after the scenario (features/support/env_sandbox.rb)
end

Given("the image at {string} can be downloaded") do |url|
  stub_request(:get, url).to_return(status: 200, body: File.binread(Rails.root.join("spec/fixtures/files/garment.jpg")),
                                    headers: { "Content-Type" => "image/jpeg" })
end

Given("the image at {string} cannot be downloaded") do |url|
  stub_request(:get, url).to_return(status: 404, body: "Not found")
end

When("I search for garments with brand {string} and keywords {string}") do |brand, keywords|
  search_for_garments(brand: brand, keywords: keywords)
end

When("I search for garments with keywords {string}") do |keywords|
  search_for_garments(keywords: keywords)
end

When("I search for garments with no brand or keywords") do
  search_for_garments
end

When("I pick the search result {string}") do |title|
  within(search_result_css(title)) { click_button("Add to wardrobe") }
end

Then("I should see {int} search result(s)") do |count|
  expect(page).to have_css("article.search-result", count: count)
end

Then("I should see the search result {string}") do |title|
  expect(page).to have_css(search_result_css(title))
end

Then("I should not see the search result {string}") do |title|
  expect(page).to have_no_css(search_result_css(title))
end

Then("the garment {string} should have an imported image") do |name|
  garment = Garment.find_by!(user_id: @user.id, name: name)
  expect(garment).to have_attributes(source: "search", image_status: "ready")
  expect(garment.image).to be_attached
  expect(garment.image.content_type).to eq("image/jpeg")
end

Then("no request should have been made to {string}") do |host|
  expect(a_request(:any, /#{Regexp.escape(host)}/)).not_to have_been_made
end
