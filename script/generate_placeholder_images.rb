#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the six garment placeholder images (design doc 6.4) as simple flat silhouettes.
# The original stock photos (misfitai-mobile/assets/stock/) are not available, so these replace them.
# Usage, from the repo root: bundle exec ruby script/generate_placeholder_images.rb
require "fileutils"
require "vips"

SIZE = 512
BACKGROUND = [ 242, 242, 240 ].freeze # --bg
INK = [ 196, 197, 190 ].freeze        # --line-strong
OUT_DIR = File.expand_path("../app/assets/images/placeholders", __dir__)

# Draws a filled trapezoid row by row: width changes linearly from top_width to bottom_width.
def trapezoid(m, center_x, top_y, bottom_y, top_width, bottom_width)
  height = bottom_y - top_y
  height.times do |i|
    width = (top_width + ((bottom_width - top_width) * i / height.to_f)).round
    m.draw_rect!(INK, center_x - (width / 2), top_y + i, width, 1, fill: true)
  end
end

def rect(m, x, y, w, h) = m.draw_rect!(INK, x, y, w, h, fill: true)
def circle(m, x, y, r, ink = INK) = m.draw_circle!(ink, x, y, r, fill: true)

SHAPES = {
  "top" => lambda do |m|
    trapezoid(m, 256, 120, 170, 260, 340) # shoulders into sleeves
    rect(m, 86, 170, 340, 70)             # sleeves
    rect(m, 166, 150, 180, 250)           # body
    circle(m, 256, 122, 34, BACKGROUND)   # neckline
  end,
  "bottom" => lambda do |m|
    rect(m, 166, 96, 180, 40)             # waistband
    trapezoid(m, 206, 136, 420, 92, 80)   # left leg
    trapezoid(m, 306, 136, 420, 92, 80)   # right leg
  end,
  "dress" => lambda do |m|
    rect(m, 206, 96, 100, 110)            # bodice
    circle(m, 256, 98, 26, BACKGROUND)    # neckline
    trapezoid(m, 256, 206, 420, 100, 280) # skirt
  end,
  "outerwear" => lambda do |m|
    trapezoid(m, 256, 100, 150, 220, 320)
    trapezoid(m, 256, 150, 430, 200, 240) # long body
    trapezoid(m, 128, 150, 380, 60, 52)   # left sleeve
    trapezoid(m, 384, 150, 380, 60, 52)   # right sleeve
    circle(m, 256, 104, 30, BACKGROUND)   # collar opening
    m.draw_rect!(BACKGROUND, 254, 134, 4, 296, fill: true) # front opening
  end,
  "shoes" => lambda do |m|
    rect(m, 120, 236, 84, 92)             # heel collar
    rect(m, 120, 280, 236, 48)            # upper
    circle(m, 352, 328, 48)               # rounded toe box, top flush with the upper
    rect(m, 110, 326, 300, 30)            # sole
    m.draw_rect!(BACKGROUND, 100, 356, 320, 60, fill: true) # trim the toe below the sole
  end,
  "accessory" => lambda do |m|
    circle(m, 256, 186, 70)               # handle
    circle(m, 256, 186, 50, BACKGROUND)
    rect(m, 156, 200, 200, 190)           # bag body
  end
}.freeze

FileUtils.mkdir_p(OUT_DIR)
SHAPES.each do |category, draw|
  canvas = Vips::Image.black(SIZE, SIZE).new_from_image(BACKGROUND).cast(:uchar)
  image = canvas.mutate { |m| draw.call(m) }
  path = File.join(OUT_DIR, "#{category}.jpg")
  image.jpegsave(path, Q: 85, strip: true)
  puts "wrote #{path.delete_prefix("#{Dir.pwd}/")}"
end
