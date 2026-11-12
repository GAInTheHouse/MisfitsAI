# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::CalendarSync, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :with_google, time_zone: "America/New_York") }
  let(:week_start) { Date.new(2026, 10, 19) } # Monday
  let(:service) { instance_double(Google::Apis::CalendarV3::CalendarService, "authorization=": nil) }
  let(:plan) { Planner::WeekPlanner.ensure_week!(user:) }

  before do
    travel_to Time.zone.parse("2026-10-19 16:00:00 UTC") # Monday noon in New York
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(service)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  def timed(summary, at)
    Google::Apis::CalendarV3::Event.new(
      summary:, start: Google::Apis::CalendarV3::EventDateTime.new(date_time: DateTime.parse(at))
    )
  end

  def all_day(summary, date)
    Google::Apis::CalendarV3::Event.new(
      summary:, start: Google::Apis::CalendarV3::EventDateTime.new(date: Date.parse(date))
    )
  end

  def calendar_returns(*items)
    allow(service).to receive(:list_events).and_return(Google::Apis::CalendarV3::Events.new(items:))
  end

  def day(offset) = plan.week_events.find_by!(date: week_start + offset)

  def stub_token_refresh(access_token: "fresh-token", error: nil)
    client = instance_double(Signet::OAuth2::Client, access_token:, expires_in: 3600)
    allow(Signet::OAuth2::Client).to receive(:new).and_return(client)
    if error
      allow(client).to receive(:fetch_access_token!).and_raise(error)
    else
      allow(client).to receive(:fetch_access_token!)
    end
    client
  end

  def expect_status_broadcast(message)
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to)
      .with([ user, :planner ], hash_including(target: "calendar_sync_status", locals: hash_including(message:)))
  end

  describe "applying events" do
    it "classifies events, overwrites all 7 days and marks the plan as synced from Google" do
      plan.week_events.find_by!(date: week_start + 6).update!(event_type: "gym", original_summary: "Old")
      calendar_returns(timed("Sprint planning", "2026-10-19T09:00:00-04:00"),
                       timed("Anniversary dinner", "2026-10-23T19:00:00-04:00"))

      expect(described_class.new(user:).sync!).to be(true)

      expect(day(0)).to have_attributes(event_type: "work_meeting", original_summary: "Sprint planning")
      expect(day(4)).to have_attributes(event_type: "date_night", original_summary: "Anniversary dinner")
      expect(day(6)).to have_attributes(event_type: "none", original_summary: nil)
      expect(plan.reload).to have_attributes(source: "google", synced_at: Time.current)
      expect(user.reload.google_calendar_connected_at).to eq(Time.current)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with([ user, :planner ], hash_including(target: "week_plan"))
      expect_status_broadcast(described_class::SUCCESS_MESSAGE)
    end

    it "keeps the first connection time on later syncs" do
      user.update!(google_calendar_connected_at: 3.days.ago)
      calendar_returns
      expect { described_class.new(user:).sync! }.not_to(change { user.reload.google_calendar_connected_at })
    end

    it "queries the week's bounds in the user's time zone" do
      user.update!(time_zone: "Asia/Tokyo")
      calendar_returns

      described_class.new(user:).sync!

      expect(service).to have_received(:list_events).with(
        "primary", hash_including(time_min: "2026-10-19T00:00:00+09:00", time_max: "2026-10-25T23:59:59+09:00",
                                  single_events: true, order_by: "startTime", max_results: 250)
      )
    end

    it "dates timed events in the user's zone and all-day events by their start date" do
      # 01:30 UTC on Tuesday is still Monday evening in New York.
      calendar_returns(timed("Client dinner", "2026-10-20T01:30:00Z"), all_day("Team offsite review", "2026-10-21"))

      described_class.new(user:).sync!

      expect(day(0)).to have_attributes(event_type: "work_meeting", original_summary: "Client dinner")
      expect(day(1).event_type).to eq("none")
      expect(day(2)).to have_attributes(event_type: "work_meeting", original_summary: "Team offsite review")
    end

    it "ignores events outside the week" do
      calendar_returns(timed("Interview", "2026-10-26T09:00:00-04:00"))
      described_class.new(user:).sync!
      expect(plan.week_events.pluck(:event_type).uniq).to eq(%w[none])
    end
  end

  describe "same-day priority" do
    it "lets a higher-priority event win regardless of order" do
      calendar_returns(timed("Morning yoga", "2026-10-19T07:00:00-04:00"),
                       timed("Date night", "2026-10-19T19:00:00-04:00"),
                       timed("Client call", "2026-10-19T12:00:00-04:00"))
      described_class.new(user:).sync!
      expect(day(0)).to have_attributes(event_type: "work_meeting", original_summary: "Client call")
    end

    it "keeps the earliest event on a tie, with all-day events before timed ones" do
      calendar_returns(timed("Design review", "2026-10-20T15:00:00-04:00"),
                       timed("Team standup", "2026-10-20T09:00:00-04:00"),
                       all_day("Conference day", "2026-10-20"))
      described_class.new(user:).sync!
      expect(day(1)).to have_attributes(event_type: "work_meeting", original_summary: "Conference day")
    end

    it "classifies a day of unmatched events as casual" do
      calendar_returns(timed("Call Mom", "2026-10-22T18:00:00-04:00"))
      described_class.new(user:).sync!
      expect(day(3)).to have_attributes(event_type: "casual", original_summary: "Call Mom")
    end
  end

  describe "tokens" do
    it "uses the stored token while it is valid for more than 60 seconds" do
      allow(Signet::OAuth2::Client).to receive(:new)
      calendar_returns
      described_class.new(user:).sync!
      expect(Signet::OAuth2::Client).not_to have_received(:new)
    end

    it "refreshes a token that expires within 60 seconds" do
      user.update!(google_token_expires_at: 30.seconds.from_now)
      stub_token_refresh(access_token: "fresh-token")
      calendar_returns

      expect(described_class.new(user:).sync!).to be(true)
      expect(user.reload).to have_attributes(google_access_token: "fresh-token",
                                             google_token_expires_at: 1.hour.from_now)
      expect(service).to have_received(:authorization=).with("fresh-token")
    end

    it "clears the tokens and asks for a reconnect on invalid_grant" do
      user.update!(google_token_expires_at: 1.minute.ago)
      stub_token_refresh(error: Signet::AuthorizationError.new("invalid_grant"))

      expect(described_class.new(user:).sync!).to be(false)
      expect(user.reload).to have_attributes(google_access_token: nil, google_refresh_token: nil)
      expect_status_broadcast(described_class::RECONNECT_MESSAGE)
    end

    it "asks for a reconnect when there is no refresh token" do
      user.update!(google_refresh_token: nil)
      expect(described_class.new(user:).sync!).to be(false)
      expect_status_broadcast(described_class::RECONNECT_MESSAGE)
    end
  end

  describe "a 401 from Google" do
    it "refreshes once and retries with the new token" do
      stub_token_refresh(access_token: "retry-token")
      calls = 0
      allow(service).to receive(:list_events) do
        calls += 1
        raise Google::Apis::AuthorizationError, "Unauthorized" if calls == 1

        Google::Apis::CalendarV3::Events.new(items: [ timed("Standup", "2026-10-19T09:00:00-04:00") ])
      end

      expect(described_class.new(user:).sync!).to be(true)
      expect(calls).to eq(2)
      expect(service).to have_received(:authorization=).with("retry-token")
      expect(day(0).event_type).to eq("work_meeting")
    end

    it "asks for a reconnect when the retry is also rejected" do
      stub_token_refresh
      allow(service).to receive(:list_events).and_raise(Google::Apis::AuthorizationError, "Unauthorized")

      expect(described_class.new(user:).sync!).to be(false)
      expect(service).to have_received(:list_events).twice
      expect(user.reload.google_refresh_token).to be_nil
      expect_status_broadcast(described_class::RECONNECT_MESSAGE)
    end
  end

  describe "other failures" do
    it "shows the couldn't-reach message and leaves the week and tokens alone" do
      plan.week_events.find_by!(date: week_start).update!(event_type: "gym")
      allow(service).to receive(:list_events).and_raise(Google::Apis::ServerError, "Backend Error")

      expect(described_class.new(user:).sync!).to be(false)
      expect(day(0).event_type).to eq("gym")
      expect(user.reload.google_refresh_token).to be_present
      expect_status_broadcast(described_class::UNREACHABLE_MESSAGE)
    end

    it "does nothing while the calendar_sync flag is off" do
      allow(Feature).to receive(:enabled?).and_call_original
      allow(Feature).to receive(:enabled?).with(:calendar_sync).and_return(false)
      expect(described_class.new(user:).sync!).to be(false)
      expect(Google::Apis::CalendarV3::CalendarService).not_to have_received(:new)
    end
  end
end
