# frozen_string_literal: true

module Media
  # A safe URL that could not be downloaded: HTTP error, timeout, network failure or a body over the limit.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class FetchError < ApplicationError; end
end
