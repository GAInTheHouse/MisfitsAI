# frozen_string_literal: true

# Phase 2 wardrobe steps (design doc 8.3). Steps still marked pending are implemented in later Phase 2 steps.

# Canonical table (design doc 8.3). Columns are Garment attributes, plus the aliases in WardrobeHelpers.
Given("my wardrobe contains:") do |table|
  raise "Sign in before adding garments (e.g. 'Given I am signed in as an onboarded user')" unless @user

  table.hashes.each do |row|
    create(:garment, user: @user, **garment_attributes_from_row(row).symbolize_keys)
  end
end

# ENV changes in these steps are undone after each scenario (features/support/env_sandbox.rb).
Given("AI image generation is disabled") do
  ENV["AI_IMAGE_GEN_ENABLED"] = "false"
end

Given("the AI blocks images for {string}") do |kind|
  Ai::Client::Fake.stub(kind, Ai::ContentBlockedError.new("Image blocked by safety filter"))
end

Given("the {string} feature is disabled") do |flag|
  ENV["FEATURE_#{flag.upcase}"] = "false"
end

When("I choose the category {string}") do |_category|
  pending "Phase 2 Step 4"
end

When("I uncheck {string}") do |_label|
  pending "Phase 2 Step 4"
end

When("I fill in {string} with a name of {int} characters") do |_field, _length|
  pending "Phase 2 Step 4"
end

When("I filter the wardrobe by {string}") do |_category|
  pending "Phase 2 Step 4"
end

When("I hide {string} from outfits") do |_name|
  pending "Phase 2 Step 4"
end

When("I show {string} in outfits") do |_name|
  pending "Phase 2 Step 4"
end

When("I delete {string} and confirm {string}") do |_name, _message|
  pending "Phase 2 Step 4"
end

Then("my wardrobe should contain {string}") do |_name|
  pending "Phase 2 Step 4"
end

Then("my wardrobe should not contain {string}") do |_name|
  pending "Phase 2 Step 4"
end

Then("my wardrobe should be empty") do
  pending "Phase 2 Step 4"
end

Then("the wardrobe count should be {int}") do |_count|
  pending "Phase 2 Step 4"
end

Then("I should see the garment {string}") do |_name|
  pending "Phase 2 Step 4"
end

Then("I should not see the garment {string}") do |_name|
  pending "Phase 2 Step 4"
end

Then("the garment {string} should show the badge {string}") do |_name, _badge|
  pending "Phase 2 Step 4"
end

Then("the garment {string} should not show the badge {string}") do |_name, _badge|
  pending "Phase 2 Step 4"
end

Then("the garment {string} should use a placeholder image") do |_name|
  pending "Phase 2 Step 5"
end

Then("the garment {string} should have a generated image") do |_name|
  pending "Phase 2 Step 5"
end

Then("the garment {string} should have formality {string} and season {string}") do |_name, _formality, _season|
  pending "Phase 2 Step 4"
end

Then("the garment {string} should have these details:") do |_name, _table|
  pending "Phase 2 Step 7"
end

Then("the garment {string} should have the fit note {string}") do |_name, _note|
  pending "Phase 2 Step 8"
end

Then("no AI image generation should have been requested") do
  pending "Phase 2 Step 5"
end

Then("I should not see {string}") do |_text|
  pending "Phase 2 Step 4"
end

Then("I should see the link {string}") do |_label|
  pending "Phase 2 Step 4"
end

Then("I should not see the link {string}") do |_label|
  pending "Phase 2 Step 4"
end

Then("I should see the button {string}") do |_label|
  pending "Phase 2 Step 7"
end

Then("I should not see the tab {string}") do |_label|
  pending "Phase 2 Step 4"
end
