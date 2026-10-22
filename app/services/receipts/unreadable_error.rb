# frozen_string_literal: true

module Receipts
  # A receipt file whose text cannot be read (a damaged or encrypted PDF).
  class UnreadableError < ApplicationError; end
end
