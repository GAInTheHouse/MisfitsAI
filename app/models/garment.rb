# frozen_string_literal: true

class Garment < ApplicationRecord
  belongs_to :user

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
  NAME_MAX_LENGTH = 80

  # Snake_case form of a garment kind, e.g. "Button-down shirt" -> "button_down_shirt" (design doc 6.8.2, 12.3).
  def self.normalize_kind(value)
    value.to_s.strip.downcase.gsub(/[\s\-]+/, "_").presence
  end

  # Forms submit "" for unset optional fields; store those as nil so "untagged" stays nil (design doc 5.3).
  normalizes :name, with: ->(value) { value.squish }
  normalizes :sub_category, with: ->(value) { normalize_kind(value) }
  normalizes :color_primary, :color_secondary, with: ->(value) { value.strip.downcase.presence }
  normalizes :pattern, :material, :formality, :seasonality, :gender, :brand, :size, :fit_notes, :source_url,
             with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :category, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true # one error for a blank category
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :image_status, inclusion: { in: IMAGE_STATUSES }
  validates :formality, inclusion: { in: FORMALITIES }, allow_nil: true
  validates :seasonality, inclusion: { in: SEASONALITIES }, allow_nil: true
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :times_recommended, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :visible, -> { where(hidden_from_recommendations: false) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(created_at: :desc) }
  # Preloads the image and its tracked variants so a grid of cards does not query per card.
  scope :with_image_variants, -> { preload(image_attachment: { blob: { variant_records: { image_attachment: :blob } } }) }

  # Design doc 6.4 / 6.7: outfit planning unlocks once there is a top and a bottom, or a dress.
  # Call on a relation; the wardrobe page and the planner use visible garments:
  # current_user.garments.visible.outfit_ready?
  def self.outfit_ready?
    categories = distinct.pluck(:category)
    categories.include?("dress") || (%w[top bottom] - categories).empty?
  end

  def tags
    [ category, formality, seasonality ].compact
  end

  def placeholder_asset
    "placeholders/#{category}.jpg"
  end

  def image_or_placeholder_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    else
      ActionController::Base.helpers.asset_path(placeholder_asset)
    end
  end
end
