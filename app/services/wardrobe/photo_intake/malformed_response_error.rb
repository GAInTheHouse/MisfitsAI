# frozen_string_literal: true

module Wardrobe
  module PhotoIntake
    # The AI answered, but not in the expected shape (design doc 6.6 responseSchema).
    class MalformedResponseError < StandardError; end
  end
end
