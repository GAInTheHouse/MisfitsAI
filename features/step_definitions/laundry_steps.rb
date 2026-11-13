# frozen_string_literal: true

Given("a signed-in user with a wardrobe of:") do |table|
  @user = FactoryBot.create(:user)
  login_as(@user, scope: :user)
  table.hashes.each do |row|
    Garment.create!(user: @user, name: row["name"], category: row["category"], formality: row["formality"], source: "manual")
  end
end

Given("today has a planned casual outfit with {string} and {string}") do |top_name, bottom_name|
  plan = FactoryBot.create(:week_plan, user: @user)
  top = @user.garments.find_by!(name: top_name)
  bottom = @user.garments.find_by!(name: bottom_name)
  @outfit = OutfitRecommendation.create!(week_plan: plan, date: Date.current, event_type: "casual", top:, bottom:)
end

When("I visit today's outfits and confirm wearing the outfit") do
  visit today_outfits_path(date: Date.current.iso8601)
  click_button "I wore this"
end

When("I visit the wear history page") do
  visit wear_history_path
end

Then("I should see {string} in the laundry basket") do |name|
  expect(page).to have_content("Laundry Basket (1)")
  expect(page).to have_content(name)
end

When("I mark {string} as washed") do |name|
  garment = @user.garments.find_by!(name:)
  within("##{ActionView::RecordIdentifier.dom_id(garment)}") do
    click_button "Mark Washed"
  end
end

Then("the laundry basket should be empty") do
  expect(page).to have_content("Laundry Basket (0)")
end
