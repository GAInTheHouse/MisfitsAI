# frozen_string_literal: true

require "vips"

# Flat garment silhouettes drawn with libvips, shared by script/generate_placeholder_images.rb (grey category
# placeholders, design doc 6.4) and script/generate_seed_images.rb (coloured demo wardrobe images, 9.4).
# Shapes are drawn on a 512x512 canvas.
module GarmentSilhouettes
  SIZE = 512

  module_function

  # Draws the shape on a background and returns a Vips::Image.
  def render(shape, ink:, background:)
    canvas = Vips::Image.black(SIZE, SIZE).new_from_image(background).cast(:uchar)
    canvas.mutate { |m| SHAPES.fetch(shape).call(Pen.new(m, ink, background)) }
  end

  # Drawing helpers bound to one canvas and its colours.
  Pen = Struct.new(:m, :ink, :background) do
    def rect(x, y, w, h, color = ink) = m.draw_rect!(color, x, y, w, h, fill: true)
    def circle(x, y, r, color = ink) = m.draw_circle!(color, x, y, r, fill: true)
    def cut_rect(x, y, w, h) = rect(x, y, w, h, background)
    def cut_circle(x, y, r) = circle(x, y, r, background)

    # Filled trapezoid, row by row: width changes linearly from top_width to bottom_width.
    def trapezoid(center_x, top_y, bottom_y, top_width, bottom_width)
      height = bottom_y - top_y
      height.times do |i|
        width = (top_width + ((bottom_width - top_width) * i / height.to_f)).round
        rect(center_x - (width / 2), top_y + i, width, 1)
      end
    end
  end

  SHAPES = {
    top: lambda do |p|
      p.trapezoid(256, 120, 170, 260, 340) # shoulders into sleeves
      p.rect(86, 170, 340, 70)             # sleeves
      p.rect(166, 150, 180, 250)           # body
      p.cut_circle(256, 122, 34)           # neckline
    end,
    bottom: lambda do |p|
      p.rect(166, 96, 180, 40)             # waistband
      p.trapezoid(206, 136, 420, 92, 80)   # left leg
      p.trapezoid(306, 136, 420, 92, 80)   # right leg
    end,
    shorts: lambda do |p|
      p.rect(166, 150, 180, 36)            # waistband
      p.trapezoid(206, 186, 330, 92, 104)  # left leg
      p.trapezoid(306, 186, 330, 92, 104)  # right leg
    end,
    dress: lambda do |p|
      p.rect(206, 96, 100, 110)            # bodice
      p.cut_circle(256, 98, 26)            # neckline
      p.trapezoid(256, 206, 420, 100, 280) # skirt
    end,
    outerwear: lambda do |p|
      p.trapezoid(256, 100, 150, 220, 320)
      p.trapezoid(256, 150, 430, 200, 240) # long body
      p.trapezoid(128, 150, 380, 60, 52)   # left sleeve
      p.trapezoid(384, 150, 380, 60, 52)   # right sleeve
      p.cut_circle(256, 104, 30)           # collar opening
      p.cut_rect(254, 134, 4, 296)         # front opening
    end,
    shoes: lambda do |p|
      p.rect(120, 236, 84, 92)             # heel collar
      p.rect(120, 280, 236, 48)            # upper
      p.circle(352, 328, 48)               # rounded toe box, top flush with the upper
      p.rect(110, 326, 300, 30)            # sole
      p.cut_rect(100, 356, 320, 60)        # trim the toe below the sole
    end,
    sneaker: lambda do |p|
      p.rect(120, 246, 84, 82)             # heel collar
      p.trapezoid(250, 268, 328, 200, 260) # low upper
      p.circle(366, 330, 34)               # toe
      p.rect(104, 326, 320, 30)            # thick sole
      p.cut_rect(96, 356, 340, 60)         # trim the toe below the sole
      p.cut_rect(214, 288, 70, 6)          # lace line
    end,
    accessory: lambda do |p|
      p.circle(256, 186, 70)               # handle
      p.cut_circle(256, 186, 50)
      p.rect(156, 200, 200, 190)           # bag body
    end,
    belt: lambda do |p|
      p.rect(76, 236, 360, 40)             # strap
      p.rect(196, 216, 80, 80)             # buckle frame
      p.cut_rect(212, 232, 48, 48)
      p.rect(226, 248, 64, 8)              # prong
    end
  }.freeze
end
