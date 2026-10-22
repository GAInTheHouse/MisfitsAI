# frozen_string_literal: true

module Ai
  # Base class for AI gateway errors (design doc 3.7).
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  class Error < StandardError; end
end
