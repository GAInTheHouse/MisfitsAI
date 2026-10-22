# frozen_string_literal: true

module Ai
  # Vertex refused the credentials or the permission (HTTP 401 or 403): fix the configuration, do not retry.
  # One class per file so Rails autoloads it wherever it is first referenced.
  class AuthenticationError < Error; end
end
