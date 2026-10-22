# frozen_string_literal: true

require_relative "demo_wardrobe_items"

# Phase 2 seeds (design doc 9.4): the demo user's 15-item wardrobe with images from db/seeds/images/.
# Repeatable: each seeded garment carries a marker (source "starter" and a "demo-seed:" source_url), and only
# garments with that marker are updated, so running db:seed again never adds copies and never touches a garment
# the user added, even one with the same name. An image is attached again only when its file changed.
# Recommendation counters and the hidden flag are left alone (the planner and the user change them).
# No AI calls and no jobs.
module DemoWardrobe
  IMAGES_DIR = File.expand_path("images", __dir__)
  GARMENT_FIELDS = %i[name category sub_category color_primary formality seasonality brand size material].freeze
  SOURCE = "starter"
  MARKER_PREFIX = "demo-seed:"

  module_function

  def seed(user)
    DEMO_WARDROBE_ITEMS.map do |item|
      garment = user.garments.find_or_initialize_by(source: SOURCE, source_url: marker(item))
      garment.assign_attributes(item.slice(*GARMENT_FIELDS))
      garment.save!
      attach_image(garment, File.join(IMAGES_DIR, item[:image]))
      garment
    end
  end

  # Stable per item (its image file name), so renaming an item in the list still updates the same garment.
  def marker(item)
    "#{MARKER_PREFIX}#{item[:image]}"
  end

  def attach_image(garment, path)
    checksum = OpenSSL::Digest::MD5.base64digest(File.binread(path))
    unless garment.image.attached? && garment.image.blob.checksum == checksum
      garment.image.attach(io: File.open(path), filename: File.basename(path), content_type: "image/jpeg")
    end
    garment.update!(image_status: "ready") unless garment.image_status == "ready"
  end
end
