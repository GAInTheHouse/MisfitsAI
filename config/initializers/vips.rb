# frozen_string_literal: true

# One libvips worker thread and no operation cache, to keep memory low on a small dyno.
# Applied only when ruby-vips really loaded: if the libvips shared library is missing, requiring ruby-vips
# fails part-way through (Active Storage rescues the LoadError) and leaves an empty Vips module behind, so
# defined?(Vips) alone is not enough.
if defined?(Vips) && Vips.respond_to?(:concurrency_set) && Vips.respond_to?(:cache_set_max)
  Vips.concurrency_set(1)
  Vips.cache_set_max(0)
end
