# frozen_string_literal: true

require "vips"

module Wardrobe
  module PhotoIntake
    # Turns an uploaded outfit photo into the JPEG sent to Gemini (design doc 6.6: "convert it to JPEG first
    # with vips"; the original also converted to RGB).
    #
    # Works from a file on disk so the photo is never held in Ruby memory: the type is checked from the first
    # bytes, the pixel count from the header (nothing decoded yet, no decompression bombs), and libvips then
    # streams the file into a thumbnail (shrinking JPEGs while loading). The result is at most MAX_SIDE pixels
    # on its longer side, upright (EXIF orientation applied), sRGB, without alpha.
    #
    #   ImagePreparer.call(path) # => Ai::Image(jpeg); raises Media::InvalidImageError
    class ImagePreparer
      ALLOWED_TYPES = %w[image/jpeg image/png image/webp image/heic].freeze
      MAX_PIXELS = 50_000_000
      MAX_SIDE = 1600
      SNIFF_BYTES = 64.kilobytes

      def self.call(path)
        path = path.to_s
        Media::ImageNormalizer.sniff!(File.binread(path, SNIFF_BYTES).to_s, allowed: ALLOWED_TYPES)

        header = Vips::Image.new_from_file(path, access: :sequential)
        if header.width * header.height > MAX_PIXELS
          raise Media::InvalidImageError.new("That photo is too large to process.", "#{header.width}x#{header.height}")
        end

        image = Vips::Image.thumbnail(path, MAX_SIDE, height: MAX_SIDE, size: :down)
        image = image.colourspace(:srgb) unless image.interpretation == :srgb
        image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
        Ai::Image.new(bytes: image.jpegsave_buffer(Q: 90, strip: true), mime_type: "image/jpeg")
      rescue Vips::Error, SystemCallError => e
        raise Media::InvalidImageError.new("We couldn't read that photo.", e.class.name)
      end
    end
  end
end
