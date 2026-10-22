# frozen_string_literal: true

# Steps used only by features/harness/test_harness.feature to check the shared test infrastructure.

Given("a chain of {int} background jobs is enqueued") do |length|
  HarnessChainJob.perform_later(1, length)
end

Then("all {int} chained jobs should have run") do |length|
  expect(HarnessChainJob.performed).to eq((1..length).to_a)
end

Then("no background jobs should be enqueued") do
  expect(enqueued_jobs).to be_empty
end

Then("the AI adapter should be the fake adapter") do
  expect(Ai::Client.current).to be_a(Ai::Client::Fake)
end

Then("the {string} feature should be off") do |flag|
  expect(Feature.enabled?(flag)).to be(false)
end

Then("the {string} feature should be on") do |flag|
  expect(Feature.enabled?(flag)).to be(true)
end

Then("AI image generation should be off") do
  expect { Ai::Client.current.generate_image(kind: :garment_image, prompt: "x") }.to raise_error(Ai::DisabledError)
end

Then("AI image generation should be on") do
  expect(Ai::Client.current.generate_image(kind: :garment_image, prompt: "x")).to be_a(Ai::Image)
end

Then("generating a {string} should be blocked") do |kind|
  expect { Ai::Client.current.generate_image(kind: kind, prompt: "x") }.to raise_error(Ai::ContentBlockedError)
end

Then("my garments should be:") do |expected|
  columns = expected.headers
  actual = @user.garments.order(:name).map do |garment|
    columns.to_h { |column| [ column, garment.public_send(column).to_s ] }
  end
  expected.diff!(actual)
end
