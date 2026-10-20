# frozen_string_literal: true

require "rails_helper"

RSpec.describe Media::ImageNormalizer do
  let(:png) do
    Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
  end

  describe ".sniff!" do
    it "returns mime for a PNG" do
      expect(described_class.sniff!(png)).to eq("image/png")
    end

    it "rejects HEIC when disabled" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("HEIC_SUPPORTED", "true").and_return("false")
      heic = File.binread(__FILE__) # not heic; stub mime
      allow(Marcel::MimeType).to receive(:for).and_return("image/heic")
      expect { described_class.sniff!(heic) }.to raise_error(Media::InvalidImageError)
    end
  end

  describe ".to_square_jpeg" do
    it "returns JPEG bytes" do
      out = described_class.to_square_jpeg(png, size: 64)
      expect(out.bytesize).to be > 100
      expect(out[0, 3].unpack1("H*")).to start_with("ffd8")
    end
  end
end
