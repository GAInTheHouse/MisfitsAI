# frozen_string_literal: true

# Cucumber must never reach a real AI provider, whatever AI_ADAPTER the shell or .env sets.
# Ai::Client.current rebuilds its adapter from ENV on every call in test, so pinning ENV is enough.
ENV["AI_ADAPTER"] = "fake"

Before do
  ENV["AI_ADAPTER"] = "fake"
  raise "Cucumber must use Ai::Client::Fake, got #{Ai::Client.current.class}" unless Ai::Client.current.is_a?(Ai::Client::Fake)
end
