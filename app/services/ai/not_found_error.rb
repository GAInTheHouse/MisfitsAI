# frozen_string_literal: true

module Ai
  # Vertex has no such model or endpoint (HTTP 404): check the model ID, project and region.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class NotFoundError < Error; end
end
