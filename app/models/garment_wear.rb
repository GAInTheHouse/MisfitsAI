# frozen_string_literal: true

class GarmentWear < ApplicationRecord
  belongs_to :user
  belongs_to :garment
  belongs_to :outfit_recommendation, optional: true

  SOURCES = %w[outfit_confirm manual].freeze

  validates :worn_on, presence: true
  validates :source, inclusion: { in: SOURCES }

  scope :recent_first, -> { order(worn_on: :desc, created_at: :desc) }
end
