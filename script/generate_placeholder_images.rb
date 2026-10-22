#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the six garment placeholder images (design doc 6.4) as simple flat silhouettes.
# The original stock photos (misfitai-mobile/assets/stock/) are not available, so these replace them.
# Usage, from the repo root: bundle exec ruby script/generate_placeholder_images.rb
require "fileutils"
require_relative "lib/garment_silhouettes"

BACKGROUND = [ 242, 242, 240 ].freeze # --bg
INK = [ 196, 197, 190 ].freeze        # --line-strong
OUT_DIR = File.expand_path("../app/assets/images/placeholders", __dir__)

FileUtils.mkdir_p(OUT_DIR)
%i[top bottom dress outerwear shoes accessory].each do |category|
  path = File.join(OUT_DIR, "#{category}.jpg")
  GarmentSilhouettes.render(category, ink: INK, background: BACKGROUND).jpegsave(path, Q: 85, strip: true)
  puts "wrote #{path.delete_prefix("#{Dir.pwd}/")}"
end
