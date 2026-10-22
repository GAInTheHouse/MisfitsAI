# frozen_string_literal: true

module Ai
  # Vertex rejected the request (HTTP 400 that is not a safety block, or another 4xx): a bad schema or payload.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class InvalidRequestError < Error; end
end
