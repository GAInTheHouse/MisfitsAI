# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client::Vertex do
  let(:client) { described_class.new }

  before do
    allow(Ai::GoogleToken).to receive(:fetch).and_return("token")
    ENV["GOOGLE_CLOUD_PROJECT"] = "test-project"
    ENV["GOOGLE_CLOUD_PROJECT_NUMBER"] = "123456789"
  end

  it "parses generate_json responses" do
    stub_request(:post, %r{aiplatform.googleapis.com.*generateContent})
      .to_return(status: 200, body: JSON.generate(
        candidates: [ { content: { parts: [ { text: '{"items":[]}' } ] } } ]
      ), headers: { "Content-Type" => "application/json" })

    result = client.generate_json(kind: :garment_extraction, prompt: "hi", schema: { type: "object" })
    expect(result).to eq("items" => [])
    expect(AiCall.last.kind).to eq("garment_extraction")
  end

  it "maps 429 to TransientError" do
    stub_request(:post, %r{aiplatform.googleapis.com.*generateContent})
      .to_return(status: 429, body: "rate limited")

    expect {
      client.generate_text(kind: :outfit_explanation, prompt: "explain")
    }.to raise_error(Ai::TransientError)
  end

  it "raises QuotaExceededError when daily budget exceeded" do
    create(:ai_call, est_cost_cents: 2000, created_at: Time.current)
    expect {
      client.generate_text(kind: :outfit_explanation, prompt: "x", user: create(:user))
    }.to raise_error(Ai::QuotaExceededError)
  end

  it "calls grounded generation" do
    stub_request(:post, %r{discoveryengine.googleapis.com.*generateGroundedContent})
      .to_return(status: 200, body: JSON.generate(
        candidates: [ { content: { parts: [ { text: "Nice outfit." } ] } } ]
      ), headers: { "Content-Type" => "application/json" })

    text = client.grounded_text(
      kind: :outfit_explanation,
      prompt: "Explain",
      facts: [ { text: "Top: shirt", title: "top" } ]
    )
    expect(text).to eq("Nice outfit.")
  end

  it "returns ranked records" do
    stub_request(:post, %r{discoveryengine.googleapis.com.*rank})
      .to_return(status: 200, body: JSON.generate(records: [ { id: "0", score: 0.9 } ]),
                 headers: { "Content-Type" => "application/json" })

    out = client.rank(kind: :search_rank, query: "shirt", records: [ { id: "0", title: "A", content: "B" } ])
    expect(out.first[:score]).to eq(0.9)
  end

  it "maps empty Imagen predictions to ContentBlockedError" do
    stub_request(:post, %r{aiplatform.googleapis.com.*:predict})
      .to_return(status: 200, body: JSON.generate(predictions: []), headers: { "Content-Type" => "application/json" })

    expect {
      client.generate_image(kind: :garment_image, prompt: "shirt")
    }.to raise_error(Ai::ContentBlockedError)
  end

  it "returns image bytes from Imagen predict" do
    stub_request(:post, %r{aiplatform.googleapis.com.*:predict})
      .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("img") } ]),
                 headers: { "Content-Type" => "application/json" })

    img = client.generate_image(kind: :garment_image, prompt: "shirt")
    expect(img.bytes).to eq("img")
  end

  it "calls generate_image_with_subject" do
    stub_request(:post, %r{aiplatform.googleapis.com.*:predict})
      .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("subj") } ]),
                 headers: { "Content-Type" => "application/json" })

    img = client.generate_image_with_subject(
      kind: :outfit_preview_subject,
      prompt: "outfit",
      subject: Ai::Image.new(bytes: "face", mime_type: "image/jpeg")
    )
    expect(img.bytes).to eq("subj")
  end

  it "calls generate_image_multimodal" do
    stub_request(:post, %r{aiplatform.googleapis.com.*generateContent})
      .to_return(status: 200, body: JSON.generate(
        candidates: [ { content: { parts: [ { inlineData: { mimeType: "image/png", data: Base64.strict_encode64("z") } } ] } } ]
      ), headers: { "Content-Type" => "application/json" })

    img = client.generate_image_multimodal(
      kind: :outfit_preview_gemini,
      prompt: "draw",
      images: [ Ai::Image.new(bytes: "a", mime_type: "image/jpeg") ]
    )
    expect(img.bytes).to eq("z")
  end
end
