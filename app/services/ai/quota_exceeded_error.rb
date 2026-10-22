# frozen_string_literal: true

module Ai
  # Our own daily caps (design doc 3.5).
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  class QuotaExceededError < Error; end
end
