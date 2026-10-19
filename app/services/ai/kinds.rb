# frozen_string_literal: true

module Ai
  module Kinds
    ALL = %w[
      outfit_explanation
      receipt_structuring
      search_rank
      garment_extraction
      receipt_extraction
      selfie_description
      garment_image
      avatar_portrait
      outfit_preview_subject
      outfit_preview_gemini
    ].freeze

    IMAGE_OUTPUT = %w[
      garment_image avatar_portrait outfit_preview_subject outfit_preview_gemini
    ].freeze

    IMAGE_INPUT = %w[
      garment_extraction receipt_extraction selfie_description outfit_preview_gemini
    ].freeze
  end
end
