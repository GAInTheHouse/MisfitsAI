# frozen_string_literal: true

# The test cache is an in-memory store that outlives a single example; start every example empty so cached
# results (e.g. garment search) never leak between tests.
RSpec.configure do |config|
  config.before { Rails.cache.clear }
end
