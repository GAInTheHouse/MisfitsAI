# frozen_string_literal: true

Given("the analytics key is configured") do
  ENV["ANALYTICS_INTERNAL_API_KEY"] = "test-analytics-key"
  ENV["ANALYTICS_SKIP_KEY_AUTH"] = "false"
end

Given("dummy metrics mode is enabled") do
  ENV["ANALYTICS_USE_DUMMY_METRICS"] = "true"
end

Given("the GA4 API is unavailable") do
  stub_ga4(raise_error: true)
end

When("I call GET {string} without a key") do |path|
  page.driver.browser.header("X-Analytics-Key", "")
  visit path
end

When("I call GET {string} with the wrong key") do |path|
  page.driver.browser.header("X-Analytics-Key", "wrong-key")
  visit path
end

When("I call GET {string} with the correct key") do |path|
  page.driver.browser.header("X-Analytics-Key", ENV.fetch("ANALYTICS_INTERNAL_API_KEY", ""))
  visit path
end

Then("the response status should be {int}") do |status|
  expect(page.status_code).to eq(status)
end

Then("the response should succeed") do
  expect(page.status_code).to be < 400
end

Then("the response should include {string}") do |key|
  body = JSON.parse(page.body)
  expect(body).to have_key(key)
end

Then("{string} should be {word}") do |key, value|
  body = JSON.parse(page.body)
  expected = case value
             when /\A-?\d+\z/ then value.to_i
             when "true" then true
             when "false" then false
             else value
             end
  expect(body[key]).to eq(expected)
end
