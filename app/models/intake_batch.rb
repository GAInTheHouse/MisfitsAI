# frozen_string_literal: true

class IntakeBatch < ApplicationRecord
  belongs_to :user
  has_many :garment_drafts, dependent: :destroy
  has_one_attached :source_file

  KINDS = %w[photo receipt].freeze
  STATUSES = %w[pending processing ready failed].freeze
  PARSER_STRATEGIES = %w[text_rules pdf_text_rules image_vision plain_text_rules].freeze
  PREVIEW_LENGTH = 600
  STALE_AFTER = 24.hours

  attribute :status, :string, default: "pending"

  # Design doc 6.12: the preview is the first 600 characters followed by "...".
  normalizes :extracted_text_preview,
             with: ->(text) { text.length > PREVIEW_LENGTH ? "#{text[0, PREVIEW_LENGTH]}..." : text }

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :progress, numericality: { only_integer: true, in: 0..100 }
  validates :parser_strategy, inclusion: { in: PARSER_STRATEGIES }, allow_nil: true

  scope :photos, -> { where(kind: "photo") }
  scope :receipts, -> { where(kind: "receipt") }
  scope :stale, ->(now = Time.current) { where(created_at: ...(now - STALE_AFTER)) }

  KINDS.each do |value|
    define_method(:"#{value}?") { kind == value }
  end

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  def finished?
    ready? || failed?
  end

  def mark_processing!(progress: self.progress)
    update!(status: "processing", progress: progress, error: nil)
  end

  def mark_ready!
    update!(status: "ready", progress: 100, error: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", error: message)
  end
end
