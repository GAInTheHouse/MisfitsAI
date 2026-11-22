# frozen_string_literal: true

# One imported Google Calendar event (issue #8). Its day's week_event keeps the winning type for the pills.
class CalendarEvent < ApplicationRecord
  belongs_to :week_event

  validates :event_type, inclusion: { in: WeekEvent::EVENT_TYPES - %w[none] }

  scope :chronological, -> { order(:all_day, :starts_at, :position) }

  def timed?
    !all_day && starts_at.present?
  end
end
