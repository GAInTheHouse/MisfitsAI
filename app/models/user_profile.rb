# frozen_string_literal: true

class UserProfile < ApplicationRecord
  belongs_to :user

  has_one_attached :avatar
  has_one_attached :pending_selfie

  GENDERS = %w[female male other].freeze
  SKIN_TONES = %w[very_light light medium_light medium medium_dark dark].freeze
  COLOR_TONES = %w[warm cool neutral].freeze
  SIZES = %w[XS S M L XL XXL].freeze
  HAIR_STYLES = %w[short_straight short_wavy long_straight long_wavy curly_afro bald].freeze
  HAIR_COLORS = %w[black dark_brown light_brown auburn blonde red grey white].freeze
  BODY_TYPES = %w[slim average broad].freeze
  AVATAR_STATUSES = %w[none pending ready failed].freeze

  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :skin_tone, inclusion: { in: SKIN_TONES }, allow_nil: true
  validates :color_tone, inclusion: { in: COLOR_TONES }, allow_nil: true
  validates :top_size, :bottom_size, inclusion: { in: SIZES }, allow_nil: true
  validates :shoe_size, length: { maximum: 10 }, allow_nil: true
  validates :hair_style, inclusion: { in: HAIR_STYLES }, allow_nil: true
  validates :hair_color, inclusion: { in: HAIR_COLORS }, allow_nil: true
  validates :body_type, inclusion: { in: BODY_TYPES }, allow_nil: true
  validates :avatar_status, inclusion: { in: AVATAR_STATUSES }
  validate :favorite_and_avoided_disjoint
  validate :birthday_format_valid

  private

  def favorite_and_avoided_disjoint
    overlap = Array(favorite_colors) & Array(avoided_colors)
    return if overlap.empty?

    errors.add(:base, "A color can't be both favorite and avoided")
  end

  def birthday_format_valid
    raw = birthday_before_type_cast
    return if raw.blank?
    return if raw.is_a?(Date)
    Date.parse(raw.to_s)
  rescue Date::Error, TypeError, ArgumentError
    errors.add(:birthday, "Use YYYY-MM-DD format")
  end
end
