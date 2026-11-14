# frozen_string_literal: true

class Garment < ApplicationRecord
  belongs_to :user
  has_many :garment_wears, dependent: :destroy

  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 256, 256 ]
    attachable.variant :card, resize_to_limit: [ 512, 512 ]
  end

  CATEGORIES = %w[top bottom dress outerwear shoes accessory].freeze
  FORMALITIES = %w[casual smart_casual business formal].freeze
  SEASONALITIES = %w[hot mild cold all_season].freeze
  GENDERS = %w[men women unisex].freeze
  SOURCES = %w[manual search photo receipt starter].freeze
  IMAGE_STATUSES = %w[pending ready failed placeholder].freeze
  LAUNDRY_STATUSES = %w[clean in_laundry].freeze
  NAME_MAX_LENGTH = 80
  DEFAULT_WASH_THRESHOLDS = { "top" => 1, "bottom" => 3, "dress" => 2, "outerwear" => 6, "shoes" => 10, "accessory" => 10 }.freeze

  def self.normalize_kind(value)
    value.to_s.strip.downcase.gsub(/[\s\-]+/, "_").presence
  end

  normalizes :name, with: ->(value) { value.squish }
  normalizes :sub_category, with: ->(value) { normalize_kind(value) }
  normalizes :color_primary, :color_secondary, with: ->(value) { value.strip.downcase.presence }
  normalizes :pattern, :material, :formality, :seasonality, :gender, :brand, :size, :fit_notes, :source_url,
             with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :category, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :image_status, inclusion: { in: IMAGE_STATUSES }
  validates :laundry_status, inclusion: { in: LAUNDRY_STATUSES }
  validates :formality, inclusion: { in: FORMALITIES }, allow_nil: true
  validates :seasonality, inclusion: { in: SEASONALITIES }, allow_nil: true
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :times_recommended, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :wears_since_wash, :wear_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :wash_threshold, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :visible, -> { where(hidden_from_recommendations: false) }
  scope :clean, -> { where(laundry_status: "clean") }
  scope :in_laundry, -> { where(laundry_status: "in_laundry") }
  scope :with_attached_image, -> { preload(image_attachment: :blob) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_image_variants, -> { preload(image_attachment: { blob: { variant_records: { image_attachment: :blob } } }) }

  def self.outfit_ready?
    categories = distinct.pluck(:category)
    categories.include?("dress") || (%w[top bottom] - categories).empty?
  end

  def effective_wash_threshold = wash_threshold || DEFAULT_WASH_THRESHOLDS.fetch(category, 2)
  def clean? = laundry_status == "clean"
  def in_laundry? = laundry_status == "in_laundry"

  def record_wear!(worn_on: Date.current, outfit_recommendation: nil, source: "outfit_confirm")
    transaction do
      wear = outfit_recommendation ? garment_wears.find_or_initialize_by(outfit_recommendation:) : garment_wears.build
      return wear if wear.persisted?

      wear.update!(user:, worn_on:, source:)
      new_since_wash = wears_since_wash + 1
      update!(
        wear_count: wear_count + 1,
        wears_since_wash: new_since_wash,
        last_worn_at: [ last_worn_at, worn_on.to_time ].compact.max,
        laundry_status: new_since_wash >= effective_wash_threshold ? "in_laundry" : laundry_status
      )
      wear
    end
  end

  def undo_wear!(outfit_recommendation:)
    transaction do
      wear = garment_wears.find_by(outfit_recommendation:)
      return unless wear

      wear.destroy!
      new_since_wash = [ wears_since_wash - 1, 0 ].max
      update!(
        wear_count: [ wear_count - 1, 0 ].max,
        wears_since_wash: new_since_wash,
        last_worn_at: garment_wears.maximum(:worn_on)&.to_time,
        laundry_status: new_since_wash < effective_wash_threshold ? "clean" : laundry_status
      )
    end
  end

  def mark_washed!(washed_at: Time.current)
    update!(laundry_status: "clean", wears_since_wash: 0, last_washed_at: washed_at)
  end

  def send_to_laundry! = update!(laundry_status: "in_laundry")
  def cost_per_wear_cents = (price_cents.present? && wear_count.positive?) ? (price_cents.to_f / wear_count).round : nil
  def tags = [ category, formality, seasonality ].compact
  def placeholder_asset = "placeholders/#{category}.jpg"

  def image_or_placeholder_url
    image.attached? ? Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true) : ActionController::Base.helpers.asset_path(placeholder_asset)
  end
end
