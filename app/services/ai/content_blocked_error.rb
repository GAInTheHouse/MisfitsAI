# frozen_string_literal: true

module Ai
  # The provider's safety filter blocked the prompt or the output, shown by an explicit safety indicator
  # (design doc 3.7). An empty result without one is Ai::InvalidResponseError.
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  class ContentBlockedError < Error; end
end
