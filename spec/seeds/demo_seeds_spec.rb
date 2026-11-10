# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo Seeds" do
  before do
    ClimateControl.modify(DEMO_PASSWORD: "password123") do
      Rails.application.load_seed
    end
  end

  it "creates the demo user with wardrobe garments" do
    demo_user = User.find_by(email: "demo@misfit.ai")
    expect(demo_user).to be_present
    expect(demo_user.garments.count).to be >= 15
  end

  it "generates week plan with 7 events and recommendations" do
    demo_user = User.find_by(email: "demo@misfit.ai")
    expect(demo_user).to be_present

    week_plan = demo_user.week_plans.last
    expect(week_plan).to be_present
    expect(week_plan.week_events.count).to eq(7)
    expect(week_plan.outfit_recommendations.count).to eq(7)
  end
end
