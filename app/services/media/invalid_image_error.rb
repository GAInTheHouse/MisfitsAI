# frozen_string_literal: true

module Media
  # Bytes that are not an allowed image type (checked by content, not by name or header).
  # One class per file so Rails autoloads it wherever it is first referenced.
  class InvalidImageError < ApplicationError; end
end
