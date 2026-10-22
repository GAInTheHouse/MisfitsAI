# frozen_string_literal: true

Given("I am signed in as a new user") do
  @user = create(:user, :new_user)
  login_as(@user, scope: :user)
end

Given("I am signed in as an onboarded user") do
  @user = create(:user, :onboarded)
  login_as(@user, scope: :user)
end

Given(/^I am on the (.+) page$/) do |page_name|
  paths = {
    "wardrobe" => wardrobe_path,
    "home" => root_path,
    "sign in" => new_user_session_path,
    "sign up" => new_user_registration_path
  }
  visit paths.fetch(page_name.downcase, root_path)
end

When("I click {string}") do |label|
  click_link_or_button(label)
end

When("I fill in {string} with {string}") do |field, value|
  fill_in field, with: value
end

When("I visit {string}") do |path|
  visit path
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

When("background jobs finish") do
  # A job can enqueue more jobs (photo extraction -> draft images; retries), and perform_enqueued_jobs
  # only runs the jobs queued when it is called, so drain until the queue is empty (design doc 8.1).
  rounds = 0
  until enqueued_jobs.empty?
    rounds += 1
    raise "Background jobs still enqueued after 20 rounds: #{enqueued_jobs.map { _1[:job] }.tally}" if rounds > 20

    perform_enqueued_jobs
  end

  # Jobs report back through Turbo Stream broadcasts. A browser (@javascript) receives them; rack-test does
  # not, so reload the page there instead (design doc 8.1). Only after a GET, never replaying a form post.
  if Capybara.current_driver == :rack_test && page.driver.browser.last_request&.get?
    visit page.driver.browser.last_request.fullpath
  end
rescue Rack::Test::Error
  nil # no page visited yet: nothing to reload
end

Given("today is {string}") do |date|
  travel_to(Time.zone.parse(date))
end

Given("the AI service fails for {string}") do |kind|
  Ai::Client::Fake.stub(kind, Ai::TransientError.new("down"))
end
