# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipts::VisionParser do
  let(:user) { create(:user) }
  let(:image) { Ai::Image.new(bytes: "jpeg", mime_type: "image/jpeg") }

  it "asks the AI with the exact prompt and schema and returns normalized items" do
    items = described_class.call(image: image, user: user) # spec/fixtures/ai/receipt_extraction.json
    call = Ai::Client::Fake.calls.sole
    expect(call).to include(kind: "receipt_extraction", prompt: Receipts::Prompts::VISION, images_in: 1, user_id: user.id)
    expect(items.map { _1.slice("name", "price", "needs_confirmation") }).to eq([
      { "name" => "Oxford Shirt", "price" => 39.9, "needs_confirmation" => false },
      { "name" => "Slim Fit Chinos", "price" => 49.9, "needs_confirmation" => true } # confidence 0.61
    ])
  end

  it "matches the design doc 6.12 vision prompt character for character" do
    documented = Rails.root.join("docs/ruby_rewrite_design_doc_v2.md").read[/\*\*`Receipts::VisionParser`\*\*.*?```text\n(.*?)\n```/m, 1]
    expect(Receipts::Prompts::VISION).to eq(documented)
  end

  describe ".normalize (design doc 6.12)" do
    def normalize(*items) = described_class.normalize("items" => items)

    it "drops items without a name" do
      expect(normalize({ "name" => " ", "category" => "top" }, { "category" => "top" })).to eq([])
    end

    it "replaces an invalid category with the one inferred from the name" do
      expect(normalize({ "name" => "Leather Belt", "category" => "belts", "confidence" => 0.9 }).sole["category"]).to eq("accessory")
    end

    it "clamps confidence to 0..0.99" do
      expect(normalize({ "name" => "Tee", "category" => "top", "confidence" => 3 }).sole["confidence"]).to eq(0.99)
      expect(normalize({ "name" => "Tee", "category" => "top", "confidence" => -1 }).sole["confidence"]).to eq(0.0)
    end

    it "computes a missing confidence with the text formula, counting the category as found" do
      item = normalize({ "name" => "Tee", "category" => "top", "price" => 12.5, "size" => "M" }).sole
      expect(item.values_at("confidence", "needs_confirmation")).to eq([ 0.85, false ])
    end

    it "keeps a missing price as nil and reads numeric strings" do
      expect(normalize({ "name" => "Tee", "category" => "top", "price" => nil }).sole["price"]).to be_nil
      expect(normalize({ "name" => "Tee", "category" => "top", "price" => "19.99" }).sole["price"]).to eq(19.99)
    end

    [ nil, "text", [], { "items" => {} } ].each do |response|
      it "raises for the malformed response #{response.inspect}" do
        expect { described_class.normalize(response) }.to raise_error(Receipts::MalformedResponseError)
      end
    end
  end
end
