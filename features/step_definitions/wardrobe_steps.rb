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

Given("the AI service recovers for {string}") do |kind|
  Ai::Client::Fake.stubs.delete(kind)
end

Given("the {string} feature is disabled") do |flag|
  ENV["FEATURE_#{flag.upcase}"] = "false"
end

When("I open the {string} tab") do |label|
  find("[role=tab]", exact_text: label).click
  expect(page).to have_css("[role=tab][aria-selected=true]", exact_text: label)
end

When("I choose the category {string}") do |category|
  # Pills hide the radio (sr-only) under its label, so click the label as a person would.
  within("#manual_garment_form") { choose(category, allow_label_click: true) }
end

When("I uncheck {string}") do |label|
  uncheck(label)
end

When("I fill in {string} with a name of {int} characters") do |field, length|
  fill_in field, with: "a" * length
end

When("I filter the wardrobe by {string}") do |category|
  within("#wardrobe_filters") { click_link(category, exact_text: true) }
end

When("I hide {string} from outfits") do |name|
  within(garment_card_css(name)) { click_button("Hide from outfits") }
end

When("I show {string} in outfits") do |name|
  within(garment_card_css(name)) { click_button("Show in outfits") }
end

When("I delete {string} and confirm {string}") do |name, message|
  # Turbo's data-turbo-confirm uses the browser's confirm dialog, so this step needs @javascript.
  accept_confirm(message) do
    within(garment_card_css(name)) { click_button("Delete") }
  end
end

Then("my wardrobe should contain {string}") do |name|
  expect(Garment.where(user_id: @user.id, name: name)).to exist
end

Then("my wardrobe should not contain {string}") do |name|
  expect(Garment.where(user_id: @user.id, name: name)).not_to exist
end

Then("my wardrobe should be empty") do
  expect(Garment.where(user_id: @user.id)).not_to exist
end

Then("the wardrobe count should be {int}") do |count|
  expect(page).to have_css("#wardrobe_count", exact_text: "#{count} #{count == 1 ? 'item' : 'items'}")
end

Then("I should see the garment {string}") do |name|
  expect(page).to have_css(garment_card_css(name))
end

Then("I should not see the garment {string}") do |name|
  expect(page).to have_no_css(garment_card_css(name))
end

Then("the garment {string} should show the badge {string}") do |name, badge|
  within(garment_card_css(name)) { expect(page).to have_css(".badge", exact_text: badge) }
end

Then("the garment {string} should not show the badge {string}") do |name, badge|
  within(garment_card_css(name)) { expect(page).to have_no_css(".badge", exact_text: badge) }
end

Then("the garment {string} should use a placeholder image") do |name|
  expect(Garment.find_by!(user_id: @user.id, name: name).image).not_to be_attached
  visit wardrobe_path
  within(garment_card_css(name)) do
    expect(page).to have_css(%(img[data-image-source="placeholder"][src*="/assets/placeholders/"]))
  end
end

Then("the garment {string} should have a generated image") do |name|
  garment = Garment.find_by!(user_id: @user.id, name: name)
  expect(garment.image).to be_attached
  expect(garment.image_status).to eq("ready")
  visit wardrobe_path
  within(garment_card_css(name)) do
    expect(page).to have_css(%(img[data-image-source="attached"][src*="/rails/active_storage/representations/"]))
  end
end

# Browser-only: waits for the job's Turbo Stream broadcast to swap the card image, without reloading.
Then("the card for {string} should update to its generated/imported image") do |name|
  within(garment_card_css(name)) do
    expect(page).to have_css(%(img[data-image-source="attached"][src*="/rails/active_storage/representations/"]))
  end
end

Then("the garment {string} should have formality {string} and season {string}") do |name, formality, season|
  expect(Garment.find_by!(user_id: @user.id, name: name)).to have_attributes(formality: formality, seasonality: season)
end

Then("the garment {string} should have these details:") do |name, table|
  garment = Garment.find_by!(user_id: @user.id, name: name)
  expected = table.hashes.first
  expect(expected.to_h { |column, _| [ column, garment.public_send(column).to_s ] }).to eq(expected)
end

Then("the garment {string} should have the fit note {string}") do |_name, _note|
  pending "Phase 2 Step 8"
end

Then("no AI image generation should have been requested") do
  expect(Ai::Client::Fake.calls.select { _1[:method] == :generate_image }).to be_empty
end

Then("the {string} field should be empty") do |label|
  expect(page).to have_field(label, with: "")
end

Then("the current URL should include {string}") do |fragment|
  expect(page).to have_current_path(/#{Regexp.escape(fragment)}/)
end

Then("the garment {string} should show the button {string}") do |name, label|
  within(garment_card_css(name)) { expect(page).to have_button(label, exact_text: true) }
end

Then("I should not see {string}") do |text|
  expect(page).to have_no_content(text)
end

Then("I should see the link {string}") do |label|
  expect(page).to have_link(label, exact_text: true)
end

Then("I should not see the link {string}") do |label|
  expect(page).to have_no_link(label, exact_text: true)
end

Then("I should see the button {string}") do |label|
  expect(page).to have_button(label)
end

Then("I should see the tab {string}") do |label|
  expect(page).to have_css("[role=tab]", exact_text: label)
end

Then("I should not see the tab {string}") do |label|
  expect(page).to have_no_css("[role=tab]", exact_text: label)
end
