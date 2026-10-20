# frozen_string_literal: true

module Media
  class InvalidImageError < ApplicationError; end

  class ImageNormalizer
    ALLOWED = %w[image/jpeg image/png image/webp image/heic].freeze

    def self.sniff!(bytes, allowed: ALLOWED)
      mime = Marcel::MimeType.for(StringIO.new(bytes))
      heic_ok = ActiveModel::Type::Boolean.new.cast(ENV.fetch("HEIC_SUPPORTED", "true"))
      allowed = allowed - [ "image/heic" ] unless heic_ok
      raise InvalidImageError.new("Unsupported image type") unless allowed.include?(mime)

      mime
    end

    def self.to_square_jpeg(bytes, size: 512, background: "#ffffff")
      sniff!(bytes)
      require "vips"
      image = Vips::Image.new_from_buffer(bytes, "")
      scale = [ size.to_f / image.width, size.to_f / image.height ].min
      resized = image.resize(scale)
      canvas = Vips::Image.black(size, size).bandjoin([ size, size ]).bandjoin([ size, size ])
      canvas = canvas.new_from_image([ 255, 255, 255 ]) if background == "#ffffff"
      x = ((size - resized.width) / 2.0).round
      y = ((size - resized.height) / 2.0).round
      composed = canvas.composite(resized, :over, x: x, y: y)
      composed.jpegsave_buffer(Q: 92)
    end
  end
end
