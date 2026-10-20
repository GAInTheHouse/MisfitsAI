# frozen_string_literal: true

class WeekPlan < ApplicationRecord
  belongs_to :user
  has_many :week_events, dependent: :destroy
  has_many :outfit_recommendations, dependent: :destroy

  SOURCES = %w[manual demo google].freeze

  validates :week_start, presence: true
  validates :week_start, uniqueness: { scope: :user_id }
  validates :source, inclusion: { in: SOURCES }, allow_nil: true
end
