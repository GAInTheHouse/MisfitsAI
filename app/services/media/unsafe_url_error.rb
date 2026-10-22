# frozen_string_literal: true

module Media
  # A URL the server must not fetch: bad scheme, credentials, blocked host or port, or a private address
  # (design doc 4.4). One class per file so Rails autoloads it wherever it is first referenced.
  class UnsafeUrlError < ApplicationError; end
end
