# frozen_string_literal: true

module Wardrobe
  module Search
    # A search problem the user can act on (design doc 6.5 errors). status is the HTTP status to answer with.
    class Error < ApplicationError
      attr_reader :status

      def initialize(user_message, status:, internal_message: nil)
        @status = status
        super(user_message, internal_message)
      end
    end
  end
end
