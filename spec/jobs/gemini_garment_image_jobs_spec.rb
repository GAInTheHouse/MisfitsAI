# frozen_string_literal: true

require "rails_helper"
require "vips"

# Both image jobs with the real Vertex adapter on the default Gemini garment image model (stubbed HTTP, no network):
# the image flows through ImageNormalizer to a 512x512 JPEG, and a safety block keeps the existing fallbacks.
RSpec.describe "Gemini garment images in jobs" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:gemini) { %r{aiplatform.googleapis.com.*/models/gemini-2\.5-flash-image:generateContent} }
  let(:png) { Vips::Image.black(300, 200).new_from_image([ 240, 240, 240 ]).cast(:uchar).pngsave_buffer }

  before do
    allow(Ai::GoogleToken).to receive(:fetch).and_return("token")
    allow(Ai::Client).to receive(:current).and_return(Ai::Client::Vertex.new)
  end

  around do |example|
    original = ENV.fetch("GARMENT_IMAGE_MODEL", nil)
    ENV.delete("GARMENT_IMAGE_MODEL")
    example.run
  ensure
    original.nil? ? ENV.delete("GARMENT_IMAGE_MODEL") : ENV["GARMENT_IMAGE_MODEL"] = original
  end

  def image_reply = JSON.generate(candidates: [ { finishReason: "STOP", content: { parts: [
    { text: "Here it is." }, { inlineData: { mimeType: "image/png", data: Base64.strict_encode64(png) } }
  ] } } ])
  def blocked_reply = JSON.generate(candidates: [ { finishReason: "IMAGE_SAFETY" } ])

  def dimensions(attachment) = Vips::Image.new_from_buffer(attachment.download, "").then { [ _1.width, _1.height ] }

  describe Wardrobe::GenerateGarmentImageJob do
    let(:garment) { create(:garment, user:, name: "Plain White T-Shirt", category: "top", color_primary: "white", image_status: "pending") }

    it "attaches a 512x512 JPEG from the Gemini image and marks the garment ready, with the unchanged prompt" do
      stub_request(:post, gemini).to_return(status: 200, body: image_reply)
      described_class.perform_now(garment.id)

      garment.reload
      expect(garment.image_status).to eq("ready")
      expect(garment.image.blob.content_type).to eq("image/jpeg")
      expect(dimensions(garment.image)).to eq([ 512, 512 ])
      expect(a_request(:post, gemini).with { JSON.parse(_1.body).dig("contents", 0, "parts", 0, "text") == Wardrobe::Prompts.garment_image(garment) })
        .to have_been_made.once
      expect(AiCall.sole).to have_attributes(kind: "garment_image", status: "ok", images_out: 1, user_id: user.id)
    end

    it "keeps the placeholder on a safety block" do
      stub_request(:post, gemini).to_return(status: 200, body: blocked_reply)
      described_class.perform_now(garment.id)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "fails with one error row and no success row when the image is not decodable" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(candidates: [ { content: { parts: [
        { inlineData: { mimeType: "image/png", data: Base64.strict_encode64(png[0, png.bytesize / 2]) } }
      ] } } ]))
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::InvalidResponseError)
      expect(garment.reload.image_status).to eq("failed")
      expect(AiCall.pluck(:status, :images_out, :est_cost_cents)).to eq([ [ "error", 0, 0 ] ])
    end

    it "fails visibly (Retry image) on a text-only response" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(candidates: [ { finishReason: "STOP", content: { parts: [ { text: "no" } ] } } ]))
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::InvalidResponseError)
      expect(garment.reload.image_status).to eq("failed")
    end
  end

  describe Wardrobe::GenerateDraftImageJob do
    let(:batch) { create(:intake_batch, user:, status: "ready", progress: 30) }
    let(:draft) do
      create(:garment_draft, intake_batch: batch, attrs: { "name" => "Straight Jeans", "item_type" => "straight jeans",
                                                           "category" => "bottom", "color_primary" => "blue" })
    end

    it "attaches a 512x512 JPEG to the draft and marks it ready" do
      stub_request(:post, gemini).to_return(status: 200, body: image_reply)
      described_class.perform_now(draft.id)

      draft.reload
      expect(draft).to be_ready
      expect(dimensions(draft.image)).to eq([ 512, 512 ])
      expect(a_request(:post, gemini).with { JSON.parse(_1.body).dig("contents", 0, "parts", 0, "text") == Wardrobe::PhotoIntake::Prompts.product_image(draft.attrs) })
        .to have_been_made.once
    end

    it "leaves a committable draft with the placeholder when the image is not an image" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(candidates: [ { content: { parts: [
        { inlineData: { mimeType: "image/png", data: Base64.strict_encode64("not an image") } }
      ] } } ]))
      # The job's catch-all finishes the draft, then re-raises so the failure is recorded (existing behaviour).
      expect { described_class.perform_now(draft.id) }.to raise_error(Ai::InvalidResponseError)
      expect(draft.reload).to have_attributes(status: "ready", error: "Product image unavailable")
      expect(draft).to be_committable
      expect(AiCall.pluck(:status)).to eq([ "error" ])
    end

    it "leaves a committable draft with the placeholder on a safety block" do
      stub_request(:post, gemini).to_return(status: 200, body: blocked_reply)
      described_class.perform_now(draft.id)
      expect(draft.reload).to have_attributes(status: "ready", error: "Product image unavailable")
      expect(draft.image).not_to be_attached
      expect(draft).to be_committable
    end
  end
end
