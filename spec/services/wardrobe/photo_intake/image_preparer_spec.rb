# frozen_string_literal: true

require "rails_helper"
require "vips"

RSpec.describe Wardrobe::PhotoIntake::ImagePreparer do
  def png(width, height, bands: 4)
    Vips::Image.black(width, height, bands: bands).new_from_image([ 120, 80, 40, 128 ].first(bands)).cast(:uchar).pngsave_buffer
  end

  def size_of(image) = Vips::Image.new_from_buffer(image.bytes, "").then { [ _1.width, _1.height, _1.bands ] }

  # The preparer reads from disk, like the job (blob.open).
  def file_with(bytes)
    Tempfile.new([ "photo", ".bin" ]).tap { |f| f.binmode; f.write(bytes); f.close }.path
  end

  def prepare(bytes) = described_class.call(file_with(bytes))

  it "returns an RGB JPEG no larger than 1600 px on its longer side" do
    result = prepare(png(3200, 1600))
    expect(result.mime_type).to eq("image/jpeg")
    expect(Marcel::MimeType.for(StringIO.new(result.bytes))).to eq("image/jpeg")
    expect(size_of(result)).to eq([ 1600, 800, 3 ])
  end

  it "does not enlarge small photos" do
    expect(size_of(prepare(png(96, 128))).first(2)).to eq([ 96, 128 ])
  end

  it "rejects bytes that are not an allowed image" do
    expect { prepare("<svg onload=alert(1)>") }.to raise_error(Media::InvalidImageError)
  end

  it "rejects an image whose header claims too many pixels, before decoding it" do
    # A real 10000x10000 PNG header; the pixel data is never decoded.
    huge = Vips::Image.black(10_000, 10_000).cast(:uchar).pngsave_buffer(compression: 9)
    expect(Vips::Image).not_to receive(:thumbnail)
    expect { prepare(huge) }.to raise_error(Media::InvalidImageError, /\A10000x10000\z/)
  end

  it "never reads the whole photo into a Ruby string" do
    path = file_with(png(400, 300))
    expect(File).not_to receive(:binread).with(path)
    allow(File).to receive(:binread).with(path, described_class::SNIFF_BYTES).and_call_original
    expect(Vips::Image).not_to receive(:new_from_buffer)
    expect(described_class.call(path).mime_type).to eq("image/jpeg")
  end

  it "turns a missing file into InvalidImageError" do
    expect { described_class.call("/nonexistent/photo.jpg") }.to raise_error(Media::InvalidImageError)
  end

  it "turns a corrupt image into InvalidImageError" do
    truncated = File.binread(Rails.root.join("spec/fixtures/files/outfit.jpg")).byteslice(0, 30)
    expect { prepare(truncated) }.to raise_error(Media::InvalidImageError)
  end
end
