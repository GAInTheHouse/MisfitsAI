# frozen_string_literal: true

module ApplicationCable
  # Action Cable connections (Turbo Stream broadcasts, design doc 2.4) need a signed-in user, read from the same
  # Warden session the pages use. Signed-out sockets are refused, so a stream name copied from a page cannot be
  # used without the account, and stops working at sign-out.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = env["warden"]&.user(:user) || reject_unauthorized_connection
    end
  end
end
