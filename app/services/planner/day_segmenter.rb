# frozen_string_literal: true

module Planner
  # One outfit's time block within a day (issue #8). Responds to #date and #event_type like a WeekEvent, so the
  # recommendation engine can take segments in place of days. #chain, when set, overrides the formality chain.
  Segment = Data.define(:date, :index, :event_type, :chain, :starts_at, :ends_at, :label, :change_reason,
                        :summaries)

  # Splits a day's calendar events into as few outfits as possible (issue #8). Pure: no DB, no time dependence.
  #
  # - Zero or one timed event: one segment of the day's type, exactly the pre-#8 behaviour.
  # - Consecutive events share an outfit when their types are compatible: the same type, or casual next to anything.
  # - A work meeting and a date night share one smart-casual outfit when the wardrobe has one
  #   (smart_casual_ready:); otherwise the user changes before dinner.
  # - Gym next to a work meeting or a date night always means a change.
  # - All-day events set the day's type (via the week_event) but never open a block of their own.
  class DaySegmenter
    MAX_SEGMENTS = 3
    WORK_TO_DINNER = %w[date_night work_meeting].freeze
    SHARED_WORK_DINNER_CHAIN = [ %w[smart_casual], %w[formal business], %w[casual] ].freeze

    Block = Struct.new(:events, :change_reason) do
      def type
        events.map(&:event_type).max_by.with_index { |t, i| [ EventClassifier.priority(t), -i ] }
      end
    end

    # time_zone: the user's zone, for labels and change reasons (stored times come back in UTC).
    def self.call(week_event:, calendar_events:, smart_casual_ready:, time_zone:)
      new(week_event:, calendar_events:, smart_casual_ready:, time_zone:).call
    end

    def initialize(week_event:, calendar_events:, smart_casual_ready:, time_zone:)
      @day = week_event
      @zone = ActiveSupport::TimeZone[time_zone] || raise(ArgumentError, "unknown time zone #{time_zone.inspect}")
      @timed = calendar_events.select(&:timed?).sort_by { [ _1.starts_at, _1.position ] }
      @smart_casual_ready = smart_casual_ready
    end

    def call
      return [ single_segment ] if @timed.size <= 1

      blocks = cap(build_blocks)
      return [ single_segment(events: @timed) ] if blocks.size == 1 && !shared_work_dinner?(blocks.first)

      blocks.each_with_index.map { |block, index| segment_for(block, index) }
    end

    private

    def build_blocks
      @timed.each_with_object([]) do |event, blocks|
        current = blocks.last
        if current && compatible?(current.type, event.event_type)
          current.events << event
        else
          blocks << Block.new([ event ], current && change_reason(current, event))
        end
      end
    end

    def compatible?(block_type, type)
      return true if block_type == type || "casual".in?([ block_type, type ])
      return @smart_casual_ready if [ block_type, type ].sort == WORK_TO_DINNER

      false
    end

    # More blocks than outfits anyone would change into: fold the last ones together.
    def cap(blocks)
      while blocks.size > MAX_SEGMENTS
        last = blocks.pop
        blocks.last.events.concat(last.events)
      end
      blocks
    end

    def shared_work_dinner?(block)
      (WORK_TO_DINNER - block.events.map(&:event_type)).empty?
    end

    def segment_for(block, index)
      first = block.events.first
      Segment.new(
        date: @day.date, index:, event_type: block.type,
        chain: shared_work_dinner?(block) ? SHARED_WORK_DINNER_CHAIN : nil,
        starts_at: first.starts_at, ends_at: block.events.filter_map(&:ends_at).max,
        label: label_for(block.events), change_reason: block.change_reason,
        summaries: block.events.map(&:summary)
      )
    end

    def single_segment(events: @timed)
      Segment.new(
        date: @day.date, index: 0, event_type: @day.event_type, chain: nil,
        starts_at: events.first&.starts_at, ends_at: events.filter_map(&:ends_at).max,
        label: events.size > 1 ? label_for(events) : nil, change_reason: nil,
        summaries: events.map(&:summary)
      )
    end

    def label_for(events)
      more = events.size > 1 ? " + #{events.size - 1} more" : ""
      "#{part_of_day(local(events.first.starts_at))}: #{events.first.summary}#{more}"
    end

    def local(time) = time.in_time_zone(@zone)

    def part_of_day(time)
      if time.hour < 12 then "Morning"
      elsif time.hour < 17 then "Afternoon"
      else "Evening"
      end
    end

    def change_reason(previous, event)
      at = "#{event.summary} at #{local(event.starts_at).strftime('%-l:%M %p').strip}"
      if event.event_type == "gym"
        "Change into workout clothes for #{at}."
      elsif previous.type == "gym"
        "Change after your workout: gym pieces don't suit #{at}."
      elsif previous.type == "work_meeting" && event.event_type == "date_night"
        "Change before #{at}: work pieces are more formal than an evening out calls for."
      else
        "Change for #{at}."
      end
    end
  end
end
