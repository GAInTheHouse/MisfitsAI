# frozen_string_literal: true

module Ai
  # Image generation kill switch, AI_IMAGE_GEN_ENABLED=false (design doc 3.5).
  # One class per file so Rails autoloads it wherever it is first referenced (e.g. retry_on in a job).
  class DisabledError < Error; end
end
