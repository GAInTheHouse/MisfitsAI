# frozen_string_literal: true

Given("I am signed in as an onboarded user with Google connected") do
  @user = create(:user, :onboarded, :with_google)
  login_as(@user, scope: :user)
end

Given("my Google calendar has these events:") do |table|
  events = table.hashes.map { |row| { date: row["date"], summary: row["summary"], time: row["time"] } }
  stub_google_calendar(events:, time_zone: @user.time_zone)
end

Given("my Google access has been revoked") do
  @user.update!(google_token_expires_at: 1.minute.ago)
  stub_google_token_revoked
end

Given("Google Calendar is unavailable") do
  stub_google_calendar_failure(status: 503)
end

Given("Google will connect the calendar account {string}") do |email|
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "calendar-uid-#{email}",
    info: { email:, name: "Calendar User" },
    credentials: { token: "connect-access", refresh_token: "connect-refresh", expires_at: 1.hour.from_now.to_i }
  )
end

When("I connect my Google Calendar") do
  visit week_plan_path
  click_button "Connect Google Calendar"
end

Then("I should be back on the week plan page") do
  expect(page).to have_current_path(week_plan_path)
end

Then("my account should be linked to the Google account {string}") do |email|
  @user.reload
  expect(@user.uid).to eq("calendar-uid-#{email}")
  expect(User.where(uid: "calendar-uid-#{email}").count).to eq(1)
end

Then("my Google tokens should be cleared") do
  expect(@user.reload.google_refresh_token).to be_nil
end
