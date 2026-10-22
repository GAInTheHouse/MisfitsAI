# frozen_string_literal: true

class GarmentDraft < ApplicationRecord
  belongs_to :intake_batch
  belongs_to :user

  has_one_attached :image

  STATUSES = %w[pending ready failed committed discarded].freeze
  # A draft can be committed while its image is still pending or after it fell back to a placeholder
  # (design doc 6.6: "A draft's image fails: that draft keeps a placeholder and can still be committed").
  COMMITTABLE_STATUSES = %w[pending ready].freeze
  # attrs keys that map onto garments columns (design doc 5.3). Receipts also store
  # confidence, needs_confirmation and source_line, which are not garment columns.
  GARMENT_KEYS = %w[name category sub_category color_primary pattern material fit_notes
                    formality seasonality brand size price_cents].freeze
  STALE_AFTER = 24.hours

  attribute :status, :string, default: "pending"

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :attrs_must_be_a_hash
  validate :user_must_own_intake_batch

  scope :ordered, -> { order(:position, :created_at) }
  scope :committable, -> { where(selected: true, status: COMMITTABLE_STATUSES) }
  scope :stale, ->(now = Time.current) { where(created_at: ...(now - STALE_AFTER)).where.not(status: "committed") }

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  def name = attrs["name"]
  def category = attrs["category"]

  def garment_attributes
    attrs.slice(*GARMENT_KEYS).compact_blank
  end

  def confidence
    attrs["confidence"]&.to_f
  end

  def needs_confirmation?
    ActiveModel::Type::Boolean.new.cast(attrs["needs_confirmation"]) || false
  end

  def committable?
    selected? && COMMITTABLE_STATUSES.include?(status)
  end

  private

  def attrs_must_be_a_hash
    errors.add(:attrs, "must be a hash") unless attrs.is_a?(Hash)
  end

  def user_must_own_intake_batch
    return if intake_batch.nil? || user_id.nil?

    errors.add(:user, "must own the intake batch") unless intake_batch.user_id == user_id
  end
end
