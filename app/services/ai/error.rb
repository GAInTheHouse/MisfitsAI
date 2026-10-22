# frozen_string_literal: true

module Ai
  # Base class for AI gateway errors (design doc 3.7).
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  # http_status and google_status are set by the Vertex adapter for provider failures (validated values only,
  # never response text), so callers and logs can tell failures apart without reading the response.
  class Error < StandardError
    attr_accessor :http_status, :google_status
  end
end
