# frozen_string_literal: true

Given("my week is:") do |table|
  raise "Sign in first" unless @user

  plan = Planner::WeekPlanner.ensure_week!(user: @user)
  table.hashes.each do |row|
    day_name = row["day"] || row["Day"]
    idx = Date::DAYNAMES.index(day_name)
    raise "Unknown day #{day_name}" unless idx

    offset = (idx - plan.week_start.wday) % 7
    date = plan.week_start + offset
    event_type = row["event_type"] || row["Event type"]
    event = plan.week_events.find_or_initialize_by(date: date)
    event.event_type = event_type
    event.original_summary = row["summary"].presence if row.key?("summary")
    event.save!
  end
end

When("I apply the demo week") do
  visit week_plan_path
  click_button "Use demo week"
end

When("I generate outfits for my week") do
  visit week_plan_path
  click_button "Generate outfits"
end

When("I sync my calendar") do
  visit week_plan_path
  click_button(page.has_button?("Sync again") ? "Sync again" : "Connect Google Calendar")
  perform_enqueued_jobs
end

Then("my week should be:") do |table|
  plan = @user.week_plans.order(:week_start).last ||
         Planner::WeekPlanner.ensure_week!(user: @user)
  table.hashes.each do |row|
    day_name = row["day"] || row["Day"]
    idx = Date::DAYNAMES.index(day_name)
    offset = (idx - plan.week_start.wday) % 7
    event = plan.week_events.find_by!(date: plan.week_start + offset)
    expect(event.event_type).to eq(row["event_type"])
    if row["summary"].present?
      expect(event.original_summary).to eq(row["summary"])
    end
  end
end

Then("I should see {int} day cards") do |count|
  expect(page).to have_css('[id^="outfit_recommendation_"]', minimum: count)
end

Then(/^(\w+)'s outfit should include "([^"]+)"/) do |day_name, garment_name|
  plan = @user.week_plans.order(:week_start).last
  idx = Date::DAYNAMES.index(day_name)
  offset = (idx - plan.week_start.wday) % 7
  rec = plan.outfit_recommendations.find_by!(date: plan.week_start + offset)
  names = rec.garments_in_display_order.map(&:name)
  expect(names).to include(garment_name)
end

Then(/^(\w+)'s outfit should not include "([^"]+)"/) do |day_name, garment_name|
  plan = @user.week_plans.order(:week_start).last
  idx = Date::DAYNAMES.index(day_name)
  offset = (idx - plan.week_start.wday) % 7
  rec = plan.outfit_recommendations.find_by!(date: plan.week_start + offset)
  names = rec.garments_in_display_order.map(&:name)
  expect(names).not_to include(garment_name)
end

Then(/^(\w+)'s outfit should be the dress "([^"]+)"/) do |day_name, garment_name|
  plan = @user.week_plans.order(:week_start).last
  idx = Date::DAYNAMES.index(day_name)
  offset = (idx - plan.week_start.wday) % 7
  rec = plan.outfit_recommendations.find_by!(date: plan.week_start + offset)
  expect(rec.dress&.name).to eq(garment_name)
end

Then(/^(\w+)'s card should show an explanation/) do |day_name|
  plan = @user.week_plans.order(:week_start).last
  idx = Date::DAYNAMES.index(day_name)
  offset = (idx - plan.week_start.wday) % 7
  rec = plan.outfit_recommendations.find_by!(date: plan.week_start + offset)
  expect(rec.reload.explanation).to be_present
end

Then(/^(\w+)'s card should show "([^"]+)"/) do |day_name, text|
  plan = @user.week_plans.order(:week_start).last
  idx = Date::DAYNAMES.index(day_name)
  offset = (idx - plan.week_start.wday) % 7
  rec = plan.outfit_recommendations.find_by!(date: plan.week_start + offset)
  visit outfits_path unless page.has_current_path?(outfits_path, ignore_query: true)
  expect(page).to have_content(text)
  expect(rec.reload.explanation).to include(text) if rec.explanation
end

Given("my time zone is {string}") do |zone|
  @user.update!(time_zone: zone)
end

Then("I should see a link {string} to the wardrobe page") do |label|
  expect(page).to have_link(label, href: wardrobe_path)
end

Then("the week plan should start on Monday {string} and end on Sunday {string}") do |first, last|
  rows = all(".week-plan-row")
  expect(rows.size).to eq(7)
  expect(rows.first).to have_content("Monday")
  expect(rows.first).to have_content(first)
  expect(rows.last).to have_content("Sunday")
  expect(rows.last).to have_content(last)
end

When("I pick {string} for {word}") do |label, day_name|
  within(".week-plan-row", text: day_name) { find("label.pill", text: label).click }
end

Then("{word} should be saved as {string}") do |day_name, event_type|
  plan = Planner::WeekPlanner.ensure_week!(user: @user)
  event = plan.week_events.detect { _1.date.strftime("%A") == day_name }
  # The pill auto-submits a Turbo PATCH; wait for it rather than sleeping.
  Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until event.reload.event_type == event_type }
  expect(event.event_type).to eq(event_type)
end

Then("my week plan source should be {string}") do |source|
  expect(Planner::WeekPlanner.ensure_week!(user: @user).source).to eq(source)
end
