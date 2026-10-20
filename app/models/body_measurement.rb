# frozen_string_literal: true

class BodyMeasurement < ApplicationRecord
  belongs_to :user

  MEASUREMENT_FIELDS = %i[height_cm weight_kg chest_cm waist_cm hips_cm inseam_cm].freeze

  MEASUREMENT_FIELDS.each do |field|
    validates field, numericality: { greater_than: 0, less_than: 300 }, allow_nil: true
  end
end
