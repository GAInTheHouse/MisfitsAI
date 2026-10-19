# frozen_string_literal: true

if defined?(Vips)
  Vips.concurrency_set(1)
  Vips.cache_set_max(0)
end
