# frozen_string_literal: true

When("I regenerate the week") do
  visit outfits_path
  click_button "Regenerate week"
end

When("I hide {string} from the outfit detail") do |garment_name|
  find("button[title='#{garment_name}']").click
  within("dialog[open], dialog:not([style*='display: none'])") do
    click_button "Hide from outfits"
  end
end

Then("{string} should be hidden from recommendations") do |garment_name|
  garment = @user.garments.find_by!(name: garment_name)
  expect(garment.reload.hidden_from_recommendations).to be true
end

Given("Monday has an outfit with no bottom") do
  plan = Planner::WeekPlanner.ensure_week!(user: @user)
  top = @user.garments.find_by(category: "top") ||
        create(:garment, user: @user, category: "top", name: "Plain Top",
               formality: "casual", source: "manual", image_status: "placeholder")
  date = plan.week_start
  plan.outfit_recommendations.find_or_initialize_by(date: date, segment_index: 0).tap do |r|
    r.event_type         = "casual"
    r.top                = top
    r.bottom             = nil
    r.dress              = nil
    r.outerwear          = nil
    r.shoes              = nil
    r.explanation_status = "ready"
    r.preview_status     = "none"
    r.save!
  end
end

Then("I should see a link to {string}") do |path|
  expect(page).to have_link(href: path)
end
