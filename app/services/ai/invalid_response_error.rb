# frozen_string_literal: true

module Ai
  # Vertex answered 2xx with something unusable: not JSON, no image without a safety reason, or unparseable output.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class InvalidResponseError < Error; end
end
