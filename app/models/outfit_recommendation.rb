# frozen_string_literal: true

class OutfitRecommendation < ApplicationRecord
  belongs_to :week_plan
  belongs_to :top, class_name: "Garment", optional: true
  belongs_to :bottom, class_name: "Garment", optional: true
  belongs_to :dress, class_name: "Garment", optional: true
  belongs_to :outerwear, class_name: "Garment", optional: true
  belongs_to :shoes, class_name: "Garment", optional: true
  has_many :garment_wears, dependent: :nullify
  has_one_attached :preview_image

  validates :explanation_status, inclusion: { in: %w[pending ready failed] }, allow_nil: true
  validates :preview_status, inclusion: { in: %w[none pending ready failed] }, allow_nil: true
  validates :segment_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  scope :in_day_order, -> { order(:date, :segment_index) }

  def worn? = worn_at.present?
  def garments_in_display_order = [ outerwear, top, dress, bottom, shoes ].compact

  def toggle_worn!
    transaction do
      if worn?
        garments_in_display_order.each { |g| g.undo_wear!(outfit_recommendation: self) }
        update!(worn_at: nil)
      else
        update!(worn_at: Time.current)
        garments_in_display_order.each { |g| g.record_wear!(worn_on: date, outfit_recommendation: self) }
      end
    end
  end
end
