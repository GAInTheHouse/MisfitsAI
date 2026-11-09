# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::CalendarSync, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :with_google) }
  let(:week_start) { Date.new(2026, 10, 19) }

  before do
    allow(Planner::Week).to receive(:current_start).and_return(week_start)
    travel_to Time.zone.parse("2026-10-19 12:00:00")
  end

  it "applies classified events to the week plan" do
    plan = Planner::WeekPlanner.ensure_week!(user:)
    service = instance_double(Google::Apis::CalendarV3::CalendarService)
    event_work = Google::Apis::CalendarV3::Event.new(
      summary: "Sprint planning",
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: "2026-10-19T09:00:00-04:00")
    )
    event_date = Google::Apis::CalendarV3::Event.new(
      summary: "Anniversary dinner",
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: "2026-10-23T19:00:00-04:00")
    )
    list = Google::Apis::CalendarV3::Events.new(items: [ event_work, event_date ])

    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(service)
    allow(service).to receive(:authorization=)
    allow(service).to receive(:list_events).and_return(list)

    expect(described_class.new(user:).sync!).to be(true)
    mon = plan.week_events.find_by(date: week_start)
    fri = plan.week_events.find_by(date: week_start + 4)
    expect(mon.event_type).to eq("work_meeting")
    expect(mon.original_summary).to eq("Sprint planning")
    expect(fri.event_type).to eq("date_night")
    expect(plan.reload.source).to eq("google")
  end

  it "clears tokens on invalid_grant" do
    user.update!(google_token_expires_at: 1.minute.ago)
    client = instance_double(Signet::OAuth2::Client, access_token: nil, expires_in: 3600)
    allow(Signet::OAuth2::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_access_token!).and_raise(Signet::AuthorizationError, "invalid_grant")

    expect(described_class.new(user:).sync!).to be(false)
    expect(user.reload.google_refresh_token).to be_nil
  end
end
