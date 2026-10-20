# frozen_string_literal: true

class ApplicationError < StandardError
  attr_reader :user_message

  def initialize(user_message, internal_message = nil)
    @user_message = user_message
    super(internal_message || user_message)
  end
end
