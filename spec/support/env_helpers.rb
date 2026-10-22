# frozen_string_literal: true

# Sets ENV for the duration of a block and always restores it.
module EnvHelpers
  def with_env(overrides)
    original = overrides.keys.to_h { [ _1, ENV[_1] ] }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end
