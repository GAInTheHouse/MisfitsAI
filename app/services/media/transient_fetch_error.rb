# frozen_string_literal: true

module Media
  # A download that may succeed if tried again: timeouts, network errors, HTTP 408, 429 and 5xx.
  # A FetchError, so callers that only rescue FetchError are unaffected.
  class TransientFetchError < FetchError; end
end
