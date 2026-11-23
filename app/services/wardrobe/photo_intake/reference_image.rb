# frozen_string_literal: true

require "vips"

module Wardrobe
  module PhotoIntake
    # Prepared (and optionally cropped) outfit photo for image-conditioned draft flatlays. The result is sent
    # to Gemini only; it is never stored on the draft or garment.
    #
    #   ReferenceImage.call(draft) # => Ai::Image(jpeg) or nil when the batch has no source photo
    class ReferenceImage
      MIN_CROP_SIDE = 64
      BOX_PAD_RATIO = 0.08

      def self.call(draft)
        new(draft).call
      end

      def initialize(draft)
        @draft = draft
        @batch = draft.intake_batch
      end

      def call
        return nil unless @batch.source_file.attached?

        @batch.source_file.open do |file|
          prepared = ImagePreparer.call(file.path)
          crop_to_box(prepared, @draft.attrs["box"]) || prepared
        end
      rescue ActiveStorage::FileNotFoundError
        nil
      end

      private

      def crop_to_box(prepared, box)
        coords = normalized_box(box)
        return nil unless coords

        image = Vips::Image.new_from_buffer(prepared.bytes, "", access: :sequential)
        y_min, x_min, y_max, x_max = padded_pixels(coords, image.width, image.height)
        return nil if (x_max - x_min) < MIN_CROP_SIDE || (y_max - y_min) < MIN_CROP_SIDE

        cropped = image.crop(x_min, y_min, x_max - x_min, y_max - y_min)
        cropped = cropped.colourspace(:srgb) unless cropped.interpretation == :srgb
        cropped = cropped.flatten(background: [ 255, 255, 255 ]) if cropped.has_alpha?
        Ai::Image.new(bytes: cropped.jpegsave_buffer(Q: 90, strip: true), mime_type: "image/jpeg")
      rescue Vips::Error
        nil
      end

      def normalized_box(box)
        return nil unless box.is_a?(Array) && box.size == 4
        return nil unless box.all? { |v| v.is_a?(Numeric) || v.to_s.match?(/\A-?\d+(\.\d+)?\z/) }

        values = box.map { |v| v.to_f }
        values = values.map { |v| v / 1000.0 } if values.any? { |v| v > 1.0 } && values.all? { |v| v.between?(0.0, 1000.0) }
        return nil unless values.all? { |v| v.between?(0.0, 1.0) }

        y_min, x_min, y_max, x_max = values
        return nil if y_max <= y_min || x_max <= x_min

        [ y_min, x_min, y_max, x_max ]
      end

      def padded_pixels(coords, width, height)
        y_min, x_min, y_max, x_max = coords
        pad_x = (x_max - x_min) * BOX_PAD_RATIO
        pad_y = (y_max - y_min) * BOX_PAD_RATIO

        x0 = ((x_min - pad_x) * width).floor.clamp(0, width - 1)
        y0 = ((y_min - pad_y) * height).floor.clamp(0, height - 1)
        x1 = ((x_max + pad_x) * width).ceil.clamp(x0 + 1, width)
        y1 = ((y_max + pad_y) * height).ceil.clamp(y0 + 1, height)
        [ y0, x0, y1, x1 ]
      end
    end
  end
end
