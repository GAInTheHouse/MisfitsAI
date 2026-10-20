# frozen_string_literal: true

class IntakeBatch < ApplicationRecord
  belongs_to :user
  has_many :garment_drafts, dependent: :destroy
  has_one_attached :source_file

  KINDS = %w[photo receipt].freeze
  STATUSES = %w[pending processing ready failed].freeze

  validates :kind, inclusion: { in: KINDS }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
