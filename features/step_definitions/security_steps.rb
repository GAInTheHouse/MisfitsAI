# frozen_string_literal: true

Given("another user owns a garment") do
  @other_user = create(:user, :onboarded, email: "other@example.com")
  @other_garment = create(:garment, user: @other_user, name: "Secret Shirt")
  @user = create(:user, :onboarded, email: "me@example.com")
  login_as(@user, scope: :user)
end

When("I try to edit the other user's garment") do
  visit edit_garment_path(@other_garment)
end

When("I try to hide the other user's garment") do
  page.driver.submit :patch, hide_garment_path(@other_garment), {}
end

When("I try to delete the other user's garment") do
  page.driver.submit :delete, garment_path(@other_garment), {}
end

Then("I should get a not found response") do
  expect(page.status_code).to eq(404).or eq(404) # rack-test
end

When("I attempt to log in {int} times quickly") do |count|
  count.times do
    visit new_user_session_path
    fill_in "Email", with: "brute@example.com"
    fill_in "Password", with: "wrong"
    click_button "Log in"
  end
end

Then("I should be rate limited") do
  expect(page.status_code).to eq(429).or have_content("Retry later")
end
