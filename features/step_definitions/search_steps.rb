# frozen_string_literal: true

# Phase 2 image-search steps (design doc 6.5, 8.3). SerpAPI and image hosts are always stubbed.
# Pending until Phase 2 Step 6 implements them.

Given("the image search returns:") do |_table|
  pending "Phase 2 Step 6: stub_serpapi(results:)"
end

Given("the image search provider returns an error") do
  pending "Phase 2 Step 6"
end

Given("the image search times out") do
  pending "Phase 2 Step 6"
end

Given("image search is not configured") do
  pending "Phase 2 Step 6"
end

Given("the image at {string} can be downloaded") do |_url|
  pending "Phase 2 Step 6"
end

Given("the image at {string} cannot be downloaded") do |_url|
  pending "Phase 2 Step 6"
end

When("I search for garments with brand {string} and keywords {string}") do |_brand, _keywords|
  pending "Phase 2 Step 6"
end

When("I search for garments with keywords {string}") do |_keywords|
  pending "Phase 2 Step 6"
end

When("I search for garments with no brand or keywords") do
  pending "Phase 2 Step 6"
end

When("I pick the search result {string}") do |_title|
  pending "Phase 2 Step 6"
end

Then("I should see {int} search result(s)") do |_count|
  pending "Phase 2 Step 6"
end

Then("I should see the search result {string}") do |_title|
  pending "Phase 2 Step 6"
end

Then("I should not see the search result {string}") do |_title|
  pending "Phase 2 Step 6"
end

Then("the garment {string} should have an imported image") do |_name|
  pending "Phase 2 Step 6"
end

Then("no request should have been made to {string}") do |_host|
  pending "Phase 2 Step 6"
end
