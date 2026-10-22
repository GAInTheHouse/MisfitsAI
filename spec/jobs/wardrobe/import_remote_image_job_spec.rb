# frozen_string_literal: true

require "rails_helper"
require "vips"

RSpec.describe Wardrobe::ImportRemoteImageJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:garment) { create(:garment, user: user, source: "search", image_status: "pending") }
  let(:url) { "https://images.example.com/oxford.jpg" }
  let(:jpeg) { File.binread(Rails.root.join("spec/fixtures/files/garment.jpg")) }

  def dimensions(attachment)
    image = Vips::Image.new_from_buffer(attachment.download, "")
    [ image.width, image.height ]
  end

  it "downloads, normalizes to a 512 square JPEG, attaches and marks the garment ready" do
    stub_request(:get, url).to_return(status: 200, body: jpeg)

    described_class.perform_now(garment.id, url)

    garment.reload
    expect(garment.image_status).to eq("ready")
    expect(garment.image.content_type).to eq("image/jpeg")
    expect(dimensions(garment.image)).to eq([ 512, 512 ])
  end

  it "accepts PNG and WebP by content, whatever the Content-Type says" do
    png = File.binread(Rails.root.join("spec/fixtures/ai/garment_image.png"))
    stub_request(:get, url).to_return(status: 200, body: png, headers: { "Content-Type" => "text/plain" })
    described_class.perform_now(garment.id, url)
    expect(garment.reload.image_status).to eq("ready")
  end

  it "broadcasts the card and thumbnail to the owner's wardrobe stream" do
    stub_request(:get, url).to_return(status: 200, body: jpeg)
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(garment.id, url) }
    expect(streams.map { _1["target"] }).to include("garment_#{garment.id}", "thumb_garment_#{garment.id}")
  end

  it "is idempotent: a garment with a ready image is not fetched again" do
    garment.image.attach(io: StringIO.new(jpeg), filename: "x.jpg", content_type: "image/jpeg")
    garment.update!(image_status: "ready")
    described_class.perform_now(garment.id, url)
    expect(a_request(:get, url)).not_to have_been_made
  end

  describe "falls back to the placeholder (design doc 6.5)" do
    it "for a download that fails" do
      stub_request(:get, url).to_return(status: 404)
      described_class.perform_now(garment.id, url)
      expect(garment.reload).to have_attributes(image_status: "placeholder")
      expect(garment.image).not_to be_attached
    end


    it "for content that is not an allowed image, even with an image Content-Type" do
      stub_request(:get, url).to_return(status: 200, body: "<html>not an image</html>", headers: { "Content-Type" => "image/jpeg" })
      described_class.perform_now(garment.id, url)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "for an oversized download" do
      stub_request(:get, url).to_return(status: 200, body: "x", headers: { "Content-Length" => 20.megabytes.to_s })
      described_class.perform_now(garment.id, url)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "for a corrupt image" do
      stub_request(:get, url).to_return(status: 200, body: jpeg.byteslice(0, 40))
      described_class.perform_now(garment.id, url)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "for a private address, without making any request" do
      described_class.perform_now(garment.id, "http://169.254.169.254/latest/meta-data/")
      expect(garment.reload.image_status).to eq("placeholder")
      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "for a redirect to a private address" do
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://10.0.0.5/secret" })
      described_class.perform_now(garment.id, url)
      expect(garment.reload.image_status).to eq("placeholder")
      expect(a_request(:get, %r{10\.0\.0\.5})).not_to have_been_made
    end

    it "and broadcasts the card with the download note" do
      stub_request(:get, url).to_return(status: 404)
      streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(garment.id, url) }
      card = streams.find { _1["target"] == "garment_#{garment.id}" }
      expect(card.at("template").text).to include("Couldn't download that image; using a placeholder.")
    end
  end

  describe "temporary failures are retried, three attempts in all" do
    [ [ "a timeout", ->(stub) { stub.to_timeout } ],
      [ "a refused connection", ->(stub) { stub.to_raise(Errno::ECONNREFUSED) } ],
      [ "HTTP 503", ->(stub) { stub.to_return(status: 503) } ],
      [ "HTTP 429", ->(stub) { stub.to_return(status: 429) } ] ].each do |label, failure|
      it "schedules a retry after #{label} and keeps the garment pending meanwhile" do
        failure.call(stub_request(:get, url))
        expect { described_class.perform_now(garment.id, url) }.to have_enqueued_job(described_class).with(garment.id, url)
        expect(garment.reload.image_status).to eq("pending")
      end
    end

    it "falls back to the placeholder after the third failed attempt" do
      stub_request(:get, url).to_timeout
      perform_enqueued_jobs { described_class.perform_later(garment.id, url) }
      expect(a_request(:get, url)).to have_been_made.times(3)
      expect(garment.reload.image_status).to eq("placeholder")
      expect(enqueued_jobs).to be_empty
    end

    it "succeeds when a later attempt works" do
      stub_request(:get, url).to_return({ status: 503 }, { status: 200, body: jpeg })
      perform_enqueued_jobs { described_class.perform_later(garment.id, url) }
      expect(garment.reload.image_status).to eq("ready")
    end

    it "does not retry permanent failures" do
      stub_request(:get, url).to_return(status: 404)
      expect { described_class.perform_now(garment.id, url) }.not_to have_enqueued_job(described_class)
      expect(garment.reload.image_status).to eq("placeholder")
    end
  end

  it "keeps the placeholder and re-raises an unexpected error, so it shows in the job queue" do
    stub_request(:get, url).to_return(status: 200, body: jpeg)
    allow(Media::ImageNormalizer).to receive(:to_square_jpeg).and_raise(RuntimeError, "boom")
    expect { described_class.perform_now(garment.id, url) }.to raise_error(RuntimeError, "boom")
    expect(garment.reload.image_status).to eq("placeholder")
  end

  it "is discarded when the garment was deleted" do
    id = garment.id
    garment.destroy!
    expect { described_class.perform_now(id, url) }.not_to raise_error
    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it "allows one import per garment at a time" do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.new(garment.id, url).concurrency_key).to include("garment-image-#{garment.id}")
  end
end
