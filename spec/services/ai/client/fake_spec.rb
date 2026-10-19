# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client::Fake do
  let(:client) { described_class.new }

  it "returns fixture json per kind" do
    result = client.generate_json(kind: :garment_extraction, prompt: "x", schema: {})
    expect(result["kind"]).to eq("garment_extraction")
  end

  it "records calls" do
    client.generate_text(kind: :outfit_explanation, prompt: "hello")
    expect(described_class.calls.last[:kind]).to eq("outfit_explanation")
  end

  it "returns fixture images and supports stub" do
    described_class.stub(:garment_image, Ai::Image.new(bytes: "x", mime_type: "image/png"))
    img = client.generate_image(kind: :garment_image, prompt: "shirt")
    expect(img.bytes).to eq("x")
  end

  it "returns grounded text with facts" do
    text = client.grounded_text(kind: :outfit_explanation, prompt: "p", facts: [ { text: "Top: shirt", title: "top" } ])
    expect(text).to include("Top: shirt")
  end

  it "uses the fake adapter when AI_ADAPTER is fake" do
    ENV["AI_ADAPTER"] = "fake"
    expect(Ai::Client.current).to be_a(described_class)
  end
end
