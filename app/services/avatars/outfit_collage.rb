# frozen_string_literal: true

module Avatars
  class OutfitCollage
    WIDTH  = 900
    HEIGHT = 300
    LEFT_COL_WIDTH = (WIDTH * 0.42).to_i   # 378
    GUTTER = 8
    DIVIDER_X = LEFT_COL_WIDTH + GUTTER
    RIGHT_X = DIVIDER_X + 1 + GUTTER
    RIGHT_WIDTH = WIDTH - RIGHT_X           # ~505
    BG_COLOR = [ 250, 250, 248 ].freeze       # #FAFAF8
    DIVIDER_COLOR = [ 217, 217, 212 ].freeze  # #D9D9D4
    BORDER_COLOR  = [ 217, 217, 212 ].freeze
    LABEL_COLOR   = [ 111, 112, 107 ].freeze  # #6F706B
    LABEL_SIZE    = 11
    MAX_LABEL_LEN = 22

    def self.build(avatar_bytes, items)
      new(avatar_bytes, items).call
    end

    def initialize(avatar_bytes, items)
      @avatar_bytes = avatar_bytes
      @items = items.first(4)
    end

    def call
      require "vips"
      canvas = Vips::Image.black(WIDTH, HEIGHT, bands: 3).linear([ 1, 1, 1 ], BG_COLOR.map { |c| c.to_f })

      canvas = paste_avatar(canvas)
      canvas = draw_divider(canvas)
      canvas = paste_garments(canvas)

      canvas.jpegsave_buffer(Q: 92)
    end

    private

    def paste_avatar(canvas)
      return canvas unless @avatar_bytes&.length&.positive?

      img = Vips::Image.new_from_buffer(@avatar_bytes, "")
      img = img.thumbnail_image(LEFT_COL_WIDTH, height: HEIGHT, size: :down, crop: :none)
      x = (LEFT_COL_WIDTH - img.width) / 2
      y = (HEIGHT - img.height) / 2
      canvas.composite2(img.cast(:uchar), :over, x: x, y: y)
    rescue StandardError
      canvas
    end

    def draw_divider(canvas)
      line = Vips::Image.black(1, HEIGHT, bands: 3).linear([ 1, 1, 1 ], DIVIDER_COLOR.map(&:to_f))
      canvas.composite2(line.cast(:uchar), :over, x: DIVIDER_X, y: 0)
    rescue StandardError
      canvas
    end

    def paste_garments(canvas)
      return canvas if @items.empty?

      cols, rows = grid_dimensions
      cell_w = RIGHT_WIDTH / cols
      cell_h = HEIGHT / rows

      @items.each_with_index do |item, idx|
        col = idx % cols
        row = idx / cols
        x = RIGHT_X + col * cell_w
        y = row * cell_h
        canvas = draw_cell(canvas, item, x, y, cell_w, cell_h)
      end

      canvas
    end

    def grid_dimensions
      case @items.size
      when 1 then [ 1, 1 ]
      when 2 then [ 2, 1 ]
      else        [ 2, 2 ]
      end
    end

    def draw_cell(canvas, item, x, y, w, h)
      # white background
      bg = Vips::Image.black(w, h, bands: 3).linear([ 1, 1, 1 ], [ 255.0, 255.0, 255.0 ])
      canvas = canvas.composite2(bg.cast(:uchar), :over, x: x, y: y)

      # garment image
      bytes = garment_bytes(item)
      if bytes
        img = Vips::Image.new_from_buffer(bytes, "").thumbnail_image(w - 4, height: h - 20, size: :down, crop: :none, kernel: :lanczos3)
        ix = x + (w - img.width) / 2
        iy = y + 2
        canvas = canvas.composite2(img.cast(:uchar), :over, x: ix, y: iy)
      end

      # label
      label = item.name.to_s.truncate(MAX_LABEL_LEN)
      begin
        txt = Vips::Image.text(label, font: "sans #{LABEL_SIZE}", rgba: false)
        txt = txt.linear([ 1, 1, 1 ], LABEL_COLOR.map(&:to_f))
        lx = x + [ 0, (w - txt.width) / 2 ].max
        ly = y + h - LABEL_SIZE - 4
        canvas = canvas.composite2(txt.cast(:uchar), :over, x: lx, y: ly)
      rescue StandardError
        # label rendering failure is non-fatal
      end

      canvas
    rescue StandardError
      canvas
    end

    def garment_bytes(item)
      if item.respond_to?(:image) && item.image.attached?
        item.image.download
      end
    rescue StandardError
      nil
    end
  end
end
