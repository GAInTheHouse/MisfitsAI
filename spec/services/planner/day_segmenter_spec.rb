# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::DaySegmenter do
  let(:date) { Date.new(2026, 10, 19) }
  let(:zone) { ActiveSupport::TimeZone["America/New_York"] }
  let(:smart_casual_ready) { true }

  def day(type) = build(:week_event, date:, event_type: type)

  def event(summary, type, from, to = nil, all_day: false, position: 0)
    build(:calendar_event, summary:, event_type: type, all_day:, position:,
                           starts_at: all_day ? nil : zone.parse("2026-10-19 #{from}"),
                           ends_at: to && zone.parse("2026-10-19 #{to}"))
  end

  def segments(type, *events)
    described_class.call(week_event: day(type), calendar_events: events, smart_casual_ready:, time_zone: zone.name)
  end

  it "keeps a day without timed events as one segment of the day's type" do
    result = segments("none")
    expect(result.size).to eq(1)
    expect(result.first).to have_attributes(index: 0, event_type: "none", chain: nil, starts_at: nil, label: nil)
  end

  it "keeps a single event as one unlabelled segment with its times" do
    result = segments("work_meeting", event("Standup", "work_meeting", "09:00", "09:30"))
    expect(result.size).to eq(1)
    expect(result.first).to have_attributes(event_type: "work_meeting", label: nil, change_reason: nil,
                                            starts_at: zone.parse("2026-10-19 09:00"),
                                            ends_at: zone.parse("2026-10-19 09:30"))
  end

  it "covers same-type and casual events with one outfit" do
    result = segments("work_meeting",
                      event("Standup", "work_meeting", "09:00", "09:30"),
                      event("Lunch with Sam", "casual", "12:00", "13:00"),
                      event("Client review", "work_meeting", "15:00", "16:00"))
    expect(result.size).to eq(1)
    expect(result.first).to have_attributes(event_type: "work_meeting", label: "Morning: Standup + 2 more",
                                            ends_at: zone.parse("2026-10-19 16:00"))
  end

  it "splits a gym session from work, with a reason on each change" do
    result = segments("work_meeting",
                      event("Morning run", "gym", "07:00", "08:00"),
                      event("Sprint planning", "work_meeting", "10:00", "11:00"),
                      event("Yoga", "gym", "18:00", "19:00"))

    expect(result.map(&:event_type)).to eq(%w[gym work_meeting gym])
    expect(result.map(&:index)).to eq([ 0, 1, 2 ])
    expect(result.first.change_reason).to be_nil
    expect(result.second.change_reason).to eq("Change after your workout: gym pieces don't suit Sprint planning at 10:00 AM.")
    expect(result.third.change_reason).to eq("Change into workout clothes for Yoga at 6:00 PM.")
    expect(result.third.label).to eq("Evening: Yoga")
  end

  context "with a work meeting and a date night" do
    let(:work) { event("Board meeting", "work_meeting", "10:00", "11:00") }
    let(:dinner) { event("Anniversary dinner", "date_night", "19:00", "21:00") }

    it "shares one smart-casual outfit when the wardrobe has one" do
      result = segments("work_meeting", work, dinner)
      expect(result.size).to eq(1)
      expect(result.first).to have_attributes(event_type: "work_meeting",
                                              chain: described_class::SHARED_WORK_DINNER_CHAIN,
                                              summaries: [ "Board meeting", "Anniversary dinner" ])
    end

    context "when the wardrobe has no smart-casual outfit" do
      let(:smart_casual_ready) { false }

      it "changes before dinner" do
        result = segments("work_meeting", work, dinner)
        expect(result.map(&:event_type)).to eq(%w[work_meeting date_night])
        expect(result.second.change_reason)
          .to eq("Change before Anniversary dinner at 7:00 PM: work pieces are more formal than an evening out calls for.")
        expect(result.map(&:chain)).to eq([ nil, nil ])
      end
    end
  end

  it "ignores all-day events when splitting" do
    result = segments("work_meeting",
                      event("Conference", "work_meeting", nil, all_day: true),
                      event("Spin class", "gym", "07:00", "08:00"))
    expect(result.size).to eq(1)
    expect(result.first).to have_attributes(event_type: "work_meeting", summaries: [ "Spin class" ])
  end

  it "orders events by start time, then position" do
    result = segments("work_meeting",
                      event("Evening gym", "gym", "18:00", position: 0),
                      event("Interview", "work_meeting", "09:00", position: 1))
    expect(result.map(&:summaries)).to eq([ [ "Interview" ], [ "Evening gym" ] ])
  end

  it "rejects an unknown time zone" do
    expect { described_class.call(week_event: day("none"), calendar_events: [], smart_casual_ready:, time_zone: "Mars/Base") }
      .to raise_error(ArgumentError)
  end

  it "never proposes more than three outfits" do
    result = segments("work_meeting",
                      event("Run", "gym", "06:00"), event("Standup", "work_meeting", "09:00"),
                      event("Pilates", "gym", "12:00"), event("Review", "work_meeting", "14:00"),
                      event("Swim", "gym", "18:00"))
    expect(result.size).to eq(described_class::MAX_SEGMENTS)
    expect(result.last.summaries).to eq(%w[Pilates Review Swim])
  end
end
