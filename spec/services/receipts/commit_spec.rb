# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipts::Commit do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch) { Receipts::Intake.from_text(user: user, text: "UNIQLO\nOxford Shirt White M $39.90\nGraphic tee", strategy: "text_rules") }
  let(:shirt) { batch.garment_drafts.ordered.first }
  let(:tee) { batch.garment_drafts.ordered.second }

  it "adds the selected drafts through AddGarments as receipt garments, marking the drafts committed" do
    garments = described_class.call(batch: batch, edits: { tee.id => { "selected" => "0" } })
    expect(garments.map(&:name)).to eq([ "Oxford Shirt White" ])
    expect(garments.first).to have_attributes(source: "receipt", brand: "Uniqlo", price_cents: 3990,
                                              fit_notes: "Receipt price: $39.90")
    expect(shirt.reload).to be_committed
    expect(tee.reload).to have_attributes(status: "ready", selected: false)
  end

  it "keeps a row without a price, without a price note" do
    garment = described_class.call(batch: batch, edits: { shirt.id => { "selected" => "0" } }).sole
    expect(garment).to have_attributes(name: "Graphic Tee", price_cents: nil, fit_notes: nil)
  end

  it "applies edits: trims, downcases the color, and reads $-prices with a comma" do
    described_class.call(batch: batch, edits: { shirt.id => { "name" => "  Oxford  Shirt ", "color_primary" => "NAVY",
                                                              "price" => "$ 42,50", "size" => "" } })
    expect(user.garments.find_by(name: "Oxford Shirt")).to have_attributes(color_primary: "navy", price_cents: 4250, size: nil)
  end

  it "keeps a parsed color when the color was not edited" do
    described_class.call(batch: batch, edits: { shirt.id => { "name" => "Oxford Shirt" } })
    expect(user.garments.find_by(name: "Oxford Shirt").color_primary).to eq("white")
  end

  it "saves nothing when a price is not a number" do
    expect { described_class.call(batch: batch, edits: { shirt.id => { "price" => "forty" } }) }
      .to raise_error(Receipts::InvalidEditError, "Price must be a number like 39.90")
    expect(user.garments).to be_empty
    expect(shirt.reload.attrs["price_cents"]).to eq(3990)
  end

  it "saves nothing when an edit makes a garment invalid" do
    expect { described_class.call(batch: batch, edits: { shirt.id => { "name" => "" } }) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.garments).to be_empty
    expect(batch.garment_drafts.reload.map(&:status)).to all(eq("ready"))
  end

  it "queues images only when asked, after the commit" do
    expect { described_class.call(batch: batch, generate_images: false) }.not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
  end

  it "never adds the same drafts twice" do
    described_class.call(batch: batch)
    expect(described_class.call(batch: batch)).to eq([])
    expect(user.garments.count).to eq(2)
  end

  it "ignores edits for drafts of other batches" do
    other = Receipts::Intake.from_text(user: create(:user), text: "Linen shirt $30", strategy: "text_rules").garment_drafts.sole
    described_class.call(batch: batch, edits: { other.id => { "name" => "Hijacked" } })
    expect(other.reload.name).to eq("Linen Shirt")
  end
end
