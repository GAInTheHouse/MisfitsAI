# frozen_string_literal: true

module Ai
  # OAuth access token for Google Cloud calls (design doc 3.4), cached until 60 seconds before it expires.
  # - GOOGLE_SERVICE_ACCOUNT_JSON set (Heroku, production): the service-account key, as before.
  # - GOOGLE_SERVICE_ACCOUNT_JSON absent or blank (local development): Application Default Credentials
  #   (`gcloud auth application-default login`, GOOGLE_APPLICATION_CREDENTIALS, or the metadata server).
  # Failures raise CredentialsError with the source and the error class only: never the token, the key, or the
  # original message (a JSON parse error can quote the key).
  class GoogleToken
    SCOPE = "https://www.googleapis.com/auth/cloud-platform"

    class CredentialsError < StandardError; end

    @mutex = Mutex.new

    class << self
      def fetch
        @mutex.synchronize do
          if @token.nil? || @expires_at.nil? || @expires_at < 60.seconds.from_now
            data = credentials.fetch_access_token!
            @token = data["access_token"]
            @expires_at = Time.current + data["expires_in"].to_i.seconds
          end
          @token
        end
      rescue Signet::AuthorizationError, Google::Auth::Error => e
        raise CredentialsError, "Could not get a Google access token from #{source} (#{e.class})", cause: nil
      end

      def reset!
        @mutex.synchronize do
          @token = nil
          @expires_at = nil
        end
      end

      # "service account" or "application default credentials"
      def source
        service_account_json ? "service account" : "application default credentials"
      end

      private

      def credentials
        if (json = service_account_json)
          begin
            Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(json), scope: SCOPE)
          rescue JSON::ParserError, ArgumentError, KeyError, TypeError => e
            raise CredentialsError, "GOOGLE_SERVICE_ACCOUNT_JSON is not a valid service account key (#{e.class})",
                  cause: nil
          end
        else
          begin
            Google::Auth.get_application_default([ SCOPE ])
          rescue StandardError => e # InitializationError when nothing is found, or an unreadable credentials file
            raise CredentialsError, "No Google credentials: set GOOGLE_SERVICE_ACCOUNT_JSON or run " \
                                    "`gcloud auth application-default login` (#{e.class})", cause: nil
          end
        end
      end

      def service_account_json
        ENV["GOOGLE_SERVICE_ACCOUNT_JSON"].presence
      end
    end
  end
end
