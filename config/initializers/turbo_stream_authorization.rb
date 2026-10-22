# frozen_string_literal: true

# Only the owner may subscribe to a user's Turbo streams (see app/channels/concerns/user_stream_authorization.rb).
Rails.application.config.to_prepare do
  Turbo::StreamsChannel.prepend(UserStreamAuthorization) unless Turbo::StreamsChannel < UserStreamAuthorization
end
