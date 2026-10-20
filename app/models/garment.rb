# frozen_string_literal: true

class Garment < ApplicationRecord
  belongs_to :user

  has_one_attached :image

  CATEGORIES = %w[top bottom dress outerwear shoes accessory].freeze
  FORMALITIES = %w[casual smart_casual business formal].freeze
  SEASONALITIES = %w[hot mild cold all_season].freeze
  GENDERS = %w[men women unisex].freeze
  SOURCES = %w[manual search photo receipt starter].freeze
  IMAGE_STATUSES = %w[pending ready failed placeholder].freeze

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :image_status, inclusion: { in: IMAGE_STATUSES }
  validates :formality, inclusion: { in: FORMALITIES }, allow_nil: true
  validates :seasonality, inclusion: { in: SEASONALITIES }, allow_nil: true
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true

  scope :visible, -> { where(hidden_from_recommendations: false) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(created_at: :desc) }

  def tags
    [ category, formality, seasonality ].compact
  end

  def image_or_placeholder_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    else
      ActionController::Base.helpers.asset_path("placeholders/#{category}.jpg")
    end
  end
end
