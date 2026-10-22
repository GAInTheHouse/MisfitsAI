# frozen_string_literal: true

module Ai
  # Vertex rate limit (HTTP 429). A TransientError, so the jobs' retry_on Ai::TransientError retries it.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class RateLimitedError < TransientError; end
end
