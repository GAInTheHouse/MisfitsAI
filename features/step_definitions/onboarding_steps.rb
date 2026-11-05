# frozen_string_literal: true

Given("I have just signed up with email {string}") do |email|
  visit new_user_registration_path
  fill_in "Email", with: email
  fill_in "Password", with: "password123"
  fill_in "Password confirmation", with: "password123"
  click_button "Sign up"
end

Then("I should be on the onboarding page") do
  expect(page).to have_current_path(onboarding_path)
end

When("I choose gender {string} and continue") do |gender|
  choose gender
  click_button "Continue"
end

When("I choose aesthetics {string} and {string} and continue") do |a1, a2|
  check a1
  check a2
  click_button "Continue"
end

When("I select {string}, {string} and {string} from the catalog") do |i1, i2, i3|
  check i1
  check i2
  check i3
end

When("I continue through step 0") do
  visit onboarding_path
  click_button "Continue"
end

When("I continue through step 1") do
  click_button "Continue"
end

When("I select {string} and {string} from the catalog") do |i1, i2|
  check i1
  check i2
end

When("I fill in the custom item name {string} with category {string}") do |name, category|
  within "[data-nested-row]", match: :last do
    fill_in "Name", with: name
    select category, from: "Category"
  end
end

Then("{string} should be disabled") do |button_text|
  expect(page).to have_button(button_text, disabled: true)
end

Given("I am on step 4 of onboarding") do
  @user = create(:user, :onboarded_step_4)
  login_as(@user, scope: :user)
  visit onboarding_path
end

Then("I should be onboarded") do
  @user.reload
  expect(@user.onboarding_completed_at).not_to be_nil
end
