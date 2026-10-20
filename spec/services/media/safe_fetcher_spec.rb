# frozen_string_literal: true

require "rails_helper"

RSpec.describe Media::SafeFetcher do
  it "blocks metadata hostnames" do
    expect {
      described_class.fetch("http://metadata.google.internal/latest/meta-data/")
    }.to raise_error(Media::UnsafeUrlError)
  end

  it "blocks file urls" do
    expect {
      described_class.fetch("file:///etc/passwd")
    }.to raise_error(Media::UnsafeUrlError)
  end

  it "fetches allowed public urls" do
    stub_request(:get, "https://example.com/image.jpg")
      .to_return(status: 200, body: File.binread(Rails.root.join("spec/fixtures/ai/garment_image.png")),
                 headers: { "Content-Type" => "image/png" })

    image = described_class.fetch("https://example.com/image.jpg")
    expect(image.bytes).to be_present
    expect(image.mime_type).to be_present
  end
end
