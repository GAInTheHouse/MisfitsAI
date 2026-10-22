# frozen_string_literal: true

# Phase 2 receipt steps (design doc 6.12, 8.3). The AI is always Ai::Client::Fake.
# Pending until Phase 2 Step 8 implements them.

Given("the AI will read these items from my receipt image:") do |_table|
  pending "Phase 2 Step 8: Ai::Client::Fake.stub(:receipt_extraction, ...)"
end

When("I paste this receipt text:") do |_text|
  pending "Phase 2 Step 8"
end

When("I upload the receipt {string}") do |_filename|
  pending "Phase 2 Step 8"
end

When("I upload an {int} MB receipt file") do |_megabytes|
  pending "Phase 2 Step 8"
end

When("I exclude the receipt row {string}") do |_name|
  pending "Phase 2 Step 8"
end

Then("I should see {int} receipt row(s)") do |_count|
  pending "Phase 2 Step 8"
end

Then("I should see a receipt row for {string} with price {string}") do |_name, _price|
  pending "Phase 2 Step 8"
end

Then("I should not see a receipt row for {string}") do |_name|
  pending "Phase 2 Step 8"
end

Then("the receipt row {string} should be flagged {string}") do |_name, _flag|
  pending "Phase 2 Step 8"
end
