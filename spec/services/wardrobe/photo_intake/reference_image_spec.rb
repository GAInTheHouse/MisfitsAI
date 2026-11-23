# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::PhotoIntake::ReferenceImage do
  let(:user) { create(:user) }
  let(:batch) do
    create(:intake_batch, user: user, status: "ready").tap do |b|
      b.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "outfit.jpg",
                           content_type: "image/jpeg")
    end
  end

  it "returns a prepared JPEG for the batch photo" do
    draft = create(:garment_draft, intake_batch: batch)
    image = described_class.call(draft)
    expect(image).to be_a(Ai::Image)
    expect(image.mime_type).to eq("image/jpeg")
    expect(image.bytes).to start_with("\xFF\xD8".b)
  end

  it "returns nil when the batch has no source photo" do
    batch.source_file.purge
    draft = create(:garment_draft, intake_batch: batch)
    expect(described_class.call(draft)).to be_nil
  end

  it "crops when a normalized box is present" do
    require "vips"
    draft = create(:garment_draft, intake_batch: batch, attrs: { "box" => [ 0.2, 0.2, 0.8, 0.8 ] })
    full = described_class.call(create(:garment_draft, intake_batch: batch))
    cropped = described_class.call(draft)
    full_w = Vips::Image.new_from_buffer(full.bytes, "").width
    crop_w = Vips::Image.new_from_buffer(cropped.bytes, "").width
    expect(crop_w).to be < full_w
  end

  it "accepts 0..1000 boxes from extraction" do
    draft = create(:garment_draft, intake_batch: batch, attrs: { "box" => [ 200, 200, 800, 800 ] })
    expect(described_class.call(draft)).to be_a(Ai::Image)
  end

  it "falls back to the full photo when the box is invalid" do
    draft = create(:garment_draft, intake_batch: batch, attrs: { "box" => [ 0, 0, 0, 0 ] })
    uncropped = described_class.call(create(:garment_draft, intake_batch: batch))
    expect(described_class.call(draft).bytes).to eq(uncropped.bytes)
  end
end
