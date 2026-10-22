# frozen_string_literal: true

# Phase 2 photo-intake steps (design doc 6.6, 8.3). The AI is always Ai::Client::Fake.
# Pending until Phase 2 Step 7 implements them.

Given("the AI will detect these garments in my photo:") do |_table|
  pending "Phase 2 Step 7: Ai::Client::Fake.stub(:garment_extraction, ...)"
end

Given("the AI will detect no garments in my photo") do
  pending "Phase 2 Step 7"
end

Given("the AI will detect {int} garments in my photo") do |_count|
  pending "Phase 2 Step 7"
end

When("I upload {string} on the Photo AI tab") do |_filename|
  pending "Phase 2 Step 7"
end

When("I upload a {int} MB photo on the Photo AI tab") do |_megabytes|
  pending "Phase 2 Step 7"
end

When("I upload a non-image file on the Photo AI tab") do
  pending "Phase 2 Step 7"
end

When("I deselect {string}") do |_name|
  pending "Phase 2 Step 7"
end

Then("I should see {int} draft garment(s)") do |_count|
  pending "Phase 2 Step 7"
end

Then("the uploaded photo should not be kept") do
  pending "Phase 2 Step 7"
end

Then("no AI analysis should have been requested") do
  pending "Phase 2 Step 7"
end
