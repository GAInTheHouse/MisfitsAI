# frozen_string_literal: true

class AiCall < ApplicationRecord
  belongs_to :user, optional: true

  STATUSES = %w[ok error blocked quota disabled].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
