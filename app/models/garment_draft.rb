# frozen_string_literal: true

class GarmentDraft < ApplicationRecord
  belongs_to :intake_batch
  belongs_to :user

  has_one_attached :image

  STATUSES = %w[pending ready failed committed discarded].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
