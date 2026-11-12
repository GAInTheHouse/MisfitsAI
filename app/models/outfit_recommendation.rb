# frozen_string_literal: true

class OutfitRecommendation < ApplicationRecord
  belongs_to :week_plan
  belongs_to :top, class_name: "Garment", optional: true
  belongs_to :bottom, class_name: "Garment", optional: true
  belongs_to :dress, class_name: "Garment", optional: true
  belongs_to :outerwear, class_name: "Garment", optional: true
  belongs_to :shoes, class_name: "Garment", optional: true

  has_one_attached :preview_image

  EXPLANATION_STATUSES = %w[pending ready failed].freeze
  PREVIEW_STATUSES = %w[none pending ready failed].freeze

  validates :explanation_status, inclusion: { in: EXPLANATION_STATUSES }, allow_nil: true
  validates :preview_status, inclusion: { in: PREVIEW_STATUSES }, allow_nil: true
  validates :segment_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :in_day_order, -> { order(:date, :segment_index) }

  def worn?
    worn_at.present?
  end

  def garments_in_display_order
    [ outerwear, top, dress, bottom, shoes ].compact
  end
end
