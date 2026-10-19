# frozen_string_literal: true

# Encryption keys for Google OAuth tokens (see design doc 4.4).
if Rails.application.credentials.dig(:active_record_encryption, :primary_key)
  # credentials take precedence when present
elsif Rails.env.local?
  Rails.application.config.active_record.encryption.primary_key = "GGoR7xSqyx7dBjIDjd8RumviPqooeL7d"
  Rails.application.config.active_record.encryption.deterministic_key = "hmLVKizoNzbIWiu1ftuTVknRgkyeRr1X"
  Rails.application.config.active_record.encryption.key_derivation_salt = "Rb8VkdX9iRT9pc2Bh3xezCBKiJ96e8XJ"
end
