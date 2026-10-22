# frozen_string_literal: true

module Receipts
  # A review edit that cannot be saved, e.g. a price that is not a number.
  class InvalidEditError < ApplicationError; end
end
