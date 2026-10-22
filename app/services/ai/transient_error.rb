# frozen_string_literal: true

module Ai
  # 429, 5xx and timeouts: jobs retry (design doc 2.4, 3.7).
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  class TransientError < Error; end
end
