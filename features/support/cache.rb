# frozen_string_literal: true

# Start every scenario with an empty cache (see spec/support/cache.rb).
Before { Rails.cache.clear }
