# frozen_string_literal: true

Then("I should be on the onboarding page") do
  expect(page).to have_current_path(onboarding_path)
end

When("I choose gender {string} and continue") do |gender|
  find("input[name='user_profile[gender]'][value='#{gender.downcase}']", visible: :any).trigger("click")
  click_button "Continue"
end

When("I choose aesthetics {string} and {string} and continue") do |a1, a2|
  expect(page).to have_text("Your aesthetic")
  key1 = a1.downcase.gsub(/\s+/, "_")
  key2 = a2.downcase.gsub(/\s+/, "_")
  find("input[name='user_profile[aesthetics][]'][value='#{key1}']", visible: :any).ancestor("label").click
  find("input[name='user_profile[aesthetics][]'][value='#{key2}']", visible: :any).ancestor("label").click
  click_button "Continue"
end

When("I select {string}, {string} and {string} from the catalog") do |i1, i2, i3|
  expect(page).to have_text("already in your closet")
  find("span", text: i1, exact_text: true).ancestor("label").click
  find("span", text: i2, exact_text: true).ancestor("label").click
  find("span", text: i3, exact_text: true).ancestor("label").click
end

When("I continue through step 0") do
  visit onboarding_path
  click_button "Continue"
end

When("I continue through step 1") do
  click_button "Continue"
end

When("I continue through step 2") do
  click_button "Continue"
end

When("I select {string} and {string} from the catalog") do |i1, i2|
  expect(page).to have_text("already in your closet")
  find("span", text: i1, exact_text: true).ancestor("label").click
  find("span", text: i2, exact_text: true).ancestor("label").click
end

When("I fill in the custom item name {string} with category {string}") do |name, category|
  expect(page).to have_css("[data-shared--nested-rows-target='row']")
  within all("[data-shared--nested-rows-target='row']").last do
    find("input[placeholder='Item name']").set(name)
    find("select[name*='[category]']").find("option", text: category).select_option
  end
end

Then("the {string} button should be disabled") do |button_text|
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
