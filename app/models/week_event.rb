# frozen_string_literal: true

class WeekEvent < ApplicationRecord
  belongs_to :week_plan
  has_many :calendar_events, -> { order(:position) }, dependent: :delete_all, inverse_of: :week_event

  EVENT_TYPES = %w[work_meeting date_night gym casual none].freeze

  validates :date, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

  def day_name
    date.strftime("%A")
  end

  def effective_event_type
    event_type == "none" ? "casual" : event_type
  end
end
