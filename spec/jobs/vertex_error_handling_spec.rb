# frozen_string_literal: true

require "rails_helper"

# The Vertex adapter's error classes reach the existing job policies unchanged: blocks keep the placeholder,
# transient errors (429 included) are retried by retry_on, and configuration or request errors fail visibly
# instead of looking like a safety block. Real adapter, stubbed HTTP (WebMock), no network.
RSpec.describe "Vertex errors in jobs" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:imagen) { %r{aiplatform.googleapis.com.*:predict} }
  let(:gemini) { %r{aiplatform.googleapis.com.*generateContent} }

  before do
    allow(Ai::GoogleToken).to receive(:fetch).and_return("token")
    allow(Ai::Client).to receive(:current).and_return(Ai::Client::Vertex.new)
  end

  def google_error(code, status) = JSON.generate(error: { code:, status:, message: "x" })

  describe Wardrobe::GenerateGarmentImageJob do
    let(:garment) { create(:garment, user:, name: "White Oxford Shirt", category: "top", image_status: "pending") }

    it "marks the garment failed (with Retry image), not placeholder, when credentials are refused (403)" do
      stub_request(:post, imagen).to_return(status: 403, body: google_error(403, "PERMISSION_DENIED"))
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::AuthenticationError)
      expect(garment.reload.image_status).to eq("failed")
    end

    it "marks the garment failed for an unknown model (404) and an invalid request (400)" do
      stub_request(:post, imagen).to_return({ status: 404, body: google_error(404, "NOT_FOUND") },
                                            { status: 400, body: google_error(400, "INVALID_ARGUMENT") })
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::NotFoundError)
      garment.update!(image_status: "pending")
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::InvalidRequestError)
      expect(garment.reload.image_status).to eq("failed")
    end

    it "keeps the placeholder for a genuine safety block" do
      stub_request(:post, imagen).to_return(status: 200, body: JSON.generate(raiFilteredReason: "filtered"))
      described_class.perform_now(garment.id)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "fails (not placeholder) for empty predictions without a safety reason" do
      stub_request(:post, imagen).to_return(status: 200, body: JSON.generate(predictions: []))
      expect { described_class.perform_now(garment.id) }.to raise_error(Ai::InvalidResponseError)
      expect(garment.reload.image_status).to eq("failed")
    end

    it "retries a rate limit through retry_on (one request per attempt), then fails after three attempts" do
      stub_request(:post, imagen).to_return(status: 429, body: google_error(429, "RESOURCE_EXHAUSTED"))

      described_class.perform_now(garment.id)
      expect(a_request(:post, imagen)).to have_been_made.once
      expect(described_class).to have_been_enqueued.with(garment.id) # the retry, scheduled by retry_on
      expect(garment.reload.image_status).to eq("pending")

      perform_enqueued_jobs { described_class.perform_later(garment.id) }
      expect(a_request(:post, imagen)).to have_been_made.times(4) # 1 earlier + 3 attempts of the new job
      expect(garment.reload.image_status).to eq("failed")
      expect(AiCall.where(error_class: "Ai::RateLimitedError").count).to eq(4)
    end
  end

  describe Wardrobe::ExtractGarmentsJob do
    let(:batch) do
      create(:intake_batch, user:, status: "processing").tap do |b|
        b.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "outfit.jpg",
                             content_type: "image/jpeg")
      end
    end

    it "fails the batch with the analysis message for a rejected request schema (400)" do
      stub_request(:post, gemini).to_return(status: 400, body: google_error(400, "INVALID_ARGUMENT"))
      expect { described_class.perform_now(batch.id) }.to raise_error(Ai::InvalidRequestError)
      expect(batch.reload).to have_attributes(status: "failed", error: described_class::ANALYZE_FAILED)
    end

    it "fails the batch for a blocked photo without raising" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(promptFeedback: { blockReason: "SAFETY" }))
      described_class.perform_now(batch.id)
      expect(batch.reload).to have_attributes(status: "failed", error: described_class::ANALYZE_FAILED)
    end

    it "retries 5xx through retry_on" do
      stub_request(:post, gemini).to_return(status: 503, body: google_error(503, "UNAVAILABLE"))
      described_class.perform_now(batch.id)
      expect(described_class).to have_been_enqueued.with(batch.id)
      expect(batch.reload.status).to eq("processing")
    end
  end
end
