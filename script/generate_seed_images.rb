#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the demo wardrobe images in db/seeds/images/ (design doc 9.4): one 512x512 JPEG per item in
# db/seeds/demo_wardrobe_items.rb, a flat silhouette in the garment's colour on white. Generated locally (no AI
# calls), so the demo works without credentials. Usage, from the repo root:
#   bundle exec ruby script/generate_seed_images.rb
require "fileutils"
require_relative "lib/garment_silhouettes"
require_relative "../db/seeds/demo_wardrobe_items"

OUT_DIR = File.expand_path("../db/seeds/images", __dir__)
WHITE = [ 255, 255, 255 ].freeze

FileUtils.mkdir_p(OUT_DIR)
DEMO_WARDROBE_ITEMS.each do |item|
  path = File.join(OUT_DIR, item[:image])
  # Very light garments get a soft outline so they stay visible on white.
  image = GarmentSilhouettes.render(item[:shape], ink: item[:rgb], background: WHITE)
  image = image.draw_rect([ 222, 222, 218 ], 0, 0, 512, 512, fill: false) if item[:rgb].min > 225
  image.jpegsave(path, Q: 85, strip: true)
  puts "wrote #{path.delete_prefix("#{Dir.pwd}/")}"
end
