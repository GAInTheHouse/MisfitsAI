# frozen_string_literal: true

module Receipts
  # The AI answered, but not as { "items" => [ {...}, ... ] } (design doc 6.12 schema).
  class MalformedResponseError < StandardError; end
end
