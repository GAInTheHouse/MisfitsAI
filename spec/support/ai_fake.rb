# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Ai::Client::Fake.reset!
    ENV["AI_ADAPTER"] = "fake"
  end
end
