# frozen_string_literal: true

require "rails_helper"
require "vips"

RSpec.describe Avatars::OutfitCollage do
  def png(width, height, bands: 3)
    Vips::Image.black(width, height, bands: bands).new_from_image([ 80, 120, 160 ].first(bands)).cast(:uchar).pngsave_buffer
  end

  def jpeg_size(bytes)
    img = Vips::Image.new_from_buffer(bytes, "")
    [ img.width, img.height, img.bands ]
  end

  def garment_item(name:, bytes: nil)
    image = double("image", attached?: bytes.present?)
    allow(image).to receive(:download).and_return(bytes) if bytes
    double(name: name, image: image)
  end

  it "returns a fixed-size JPEG even with no avatar and no garments" do
    jpeg = described_class.build(nil, [])
    expect(jpeg.bytesize).to be > 100
    expect(jpeg_size(jpeg)).to eq([ described_class::WIDTH, described_class::HEIGHT, 3 ])
  end

  it "pastes an avatar when bytes are provided" do
    avatar = png(200, 400)
    jpeg = described_class.build(avatar, [])
    expect(jpeg_size(jpeg)).to eq([ described_class::WIDTH, described_class::HEIGHT, 3 ])
  end

  it "lays out one or two garment cells in a single row" do
    thumb = png(120, 120)
    one = [ garment_item(name: "White Tee", bytes: thumb) ]
    two = one + [ garment_item(name: "Blue Jeans", bytes: thumb) ]

    expect { described_class.build(nil, one) }.not_to raise_error
    expect { described_class.build(nil, two) }.not_to raise_error
  end

  it "caps the grid at four labeled items" do
    thumb = png(64, 64)
    items = Array.new(6) { |i| garment_item(name: "Item #{i}", bytes: thumb) }
    expect { described_class.build(nil, items) }.not_to raise_error
  end

  it "renders a name-only cell when the garment has no image" do
    items = [ garment_item(name: "Scarf", bytes: nil) ]
    jpeg = described_class.build(nil, items)
    expect(jpeg.bytesize).to be > 100
  end
end
