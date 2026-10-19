# frozen_string_literal: true

Given("I have just signed up with email {string}") do |email|
  visit new_user_registration_path
  fill_in "Email", with: email
  fill_in "Password", with: "password123"
  fill_in "Password confirmation", with: "password123"
  click_button "Sign up"
end

When("I sign in as {string} with password {string}") do |email, password|
  visit new_user_session_path
  fill_in "Email", with: email
  fill_in "Password", with: password
  click_button "Log in"
end

Given("I am signed in as {string}") do |email|
  user = User.find_by!(email: email)
  login_as(user, scope: :user)
end

Given("a user exists with email {string}") do |email|
  create(:user, :onboarded, email: email, password: "password123", password_confirmation: "password123")
end

Given("a user exists with email {string} and password {string}") do |email, password|
  create(:user, :onboarded, email: email, password: password, password_confirmation: password)
end

Given("Google OAuth returns a new user {string}") do |email|
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "google-uid-#{email.hash.abs}",
    info: { email: email, name: "Google User" },
    credentials: { token: "access-token", refresh_token: "refresh-token", expires_at: 1.hour.from_now.to_i }
  )
end

Given("Google OAuth returns provider uid for {string}") do |email|
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "linked-uid",
    info: { email: email, name: "Linked User" },
    credentials: { token: "access-token", refresh_token: "refresh-token", expires_at: 1.hour.from_now.to_i }
  )
end

When("I post Google OAuth callback") do
  visit user_google_oauth2_omniauth_callback_path
end

When("Google OAuth fails") do
  OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
  visit user_google_oauth2_omniauth_callback_path
end

Then("I should be on the wardrobe page") do
  expect(page.current_path).to eq(wardrobe_path)
end

Then("the user {string} should have Google linked") do |email|
  user = User.find_by!(email: email)
  expect(user.provider).to eq("google_oauth2")
  expect(user.uid).to be_present
end

Then("Google tokens should be encrypted for {string}") do |email|
  user = User.find_by!(email: email)
  raw = User.connection.select_value("SELECT google_access_token FROM users WHERE id = '#{user.id}'")
  expect(raw).not_to eq("access-token")
  expect(user.google_access_token).to eq("access-token")
end
