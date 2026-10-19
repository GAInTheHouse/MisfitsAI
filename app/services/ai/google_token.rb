# frozen_string_literal: true

module Ai
  class GoogleToken
    SCOPE = "https://www.googleapis.com/auth/cloud-platform"

    @mutex = Mutex.new

    class << self
      def fetch
        @mutex.synchronize do
          if @token.nil? || @expires_at.nil? || @expires_at < 60.seconds.from_now
            json = ENV.fetch("GOOGLE_SERVICE_ACCOUNT_JSON", "{}")
            creds = Google::Auth::ServiceAccountCredentials.make_creds(
              json_key_io: StringIO.new(json), scope: SCOPE
            )
            data = creds.fetch_access_token!
            @token = data["access_token"]
            @expires_at = Time.current + data["expires_in"].to_i.seconds
          end
          @token
        end
      end

      def reset!
        @mutex.synchronize do
          @token = nil
          @expires_at = nil
        end
      end
    end
  end
end
