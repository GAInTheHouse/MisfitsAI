# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Today's outfits timeline (issue #8)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :onboarded, time_zone: "America/New_York") }
  let(:zone) { ActiveSupport::TimeZone[user.time_zone] }
  let(:plan) { Planner::WeekPlanner.ensure_week!(user:) }
  let(:shirt) { create(:garment, :top, user:, name: "Oxford Shirt") }

  before do
    travel_to zone.parse("2026-10-21 08:00") # Wednesday
    sign_in user
  end

  def outfit(date:, index: 0, **attrs)
    create(:outfit_recommendation, week_plan: plan, date:, segment_index: index, top: shirt, **attrs)
  end

  it "shows today's outfits in time order, with times and change reasons" do
    outfit(date: Date.new(2026, 10, 21), index: 1, event_type: "work_meeting", segment_label: "Morning: Standup",
           starts_at: zone.parse("2026-10-21 10:00"), ends_at: zone.parse("2026-10-21 11:00"),
           change_reason: "Change after your workout.")
    outfit(date: Date.new(2026, 10, 21), index: 0, event_type: "gym", starts_at: zone.parse("2026-10-21 07:00"))

    get today_outfits_path

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("h1").text).to eq("Today's outfits")
    items = html.css(".timeline-segment")
    expect(items.map { _1.at_css(".pill").text }).to eq([ "Gym", "Work meeting" ])
    expect(items[1].text).to include("10:00 AM", "11:00 AM", "Morning: Standup", "Change after your workout.")
    expect(html.text).to include("2 outfits today")
  end

  it "shows another day of the week and links to its neighbours" do
    outfit(date: Date.new(2026, 10, 19), event_type: "casual")
    get today_outfits_path(date: "2026-10-19")
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("h1").text).to eq("Monday's outfits")
    expect(html.css("nav[aria-label=Day] a").map(&:text)).to eq([ "Tuesday →" ])
  end

  it "falls back to today for a date outside the week or an invalid one" do
    [ "2026-11-30", "not-a-date" ].each do |date|
      get today_outfits_path(date:)
      expect(Nokogiri::HTML(response.body).at_css("h1").text).to eq("Today's outfits")
    end
  end

  it "asks to plan the week when there are no outfits" do
    get today_outfits_path
    expect(response.body).to include("Plan your week first.")
  end

  describe "PATCH /outfits/:id/wear" do
    let!(:rec) { outfit(date: Date.new(2026, 10, 21), event_type: "casual") }

    it "toggles worn and re-renders the segment for Turbo" do
      patch wear_outfit_path(rec), as: :turbo_stream
      expect(rec.reload.worn_at).to eq(Time.current)
      expect(response.body).to include(%(target="timeline_outfit_recommendation_#{rec.id}"), "Worn ✓ (undo)")

      patch wear_outfit_path(rec)
      expect(rec.reload.worn_at).to be_nil
      expect(response).to redirect_to(today_outfits_path(date: "2026-10-21"))
    end

    it "returns 404 for another user's outfit" do
      other_plan = create(:week_plan, user: create(:user, :onboarded))
      other = create(:outfit_recommendation, week_plan: other_plan)
      patch wear_outfit_path(other)
      expect(response).to have_http_status(:not_found)
      expect(other.reload.worn_at).to be_nil
    end
  end
end
