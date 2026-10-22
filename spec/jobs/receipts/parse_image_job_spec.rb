# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipts::ParseImageJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch) do
    create(:intake_batch, :receipt, user: user, status: "processing", parser_strategy: "image_vision").tap do |b|
      b.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/receipt.jpg")), filename: "r.jpg",
                           content_type: "image/jpeg")
    end
  end

  def run
    perform_enqueued_jobs(only: [ described_class, ActiveStorage::PurgeJob ]) { described_class.perform_later(batch.id) }
    batch.reload
  end

  def vision_calls = Ai::Client::Fake.calls.select { _1[:kind] == "receipt_extraction" }

  it "reads the receipt image into ready drafts and deletes the image" do
    run
    expect(batch).to have_attributes(status: "ready", progress: 100)
    expect(batch.garment_drafts.ordered.map { _1.attrs.slice("name", "price_cents", "needs_confirmation") }).to eq([
      { "name" => "Oxford Shirt", "price_cents" => 3990, "needs_confirmation" => false },
      { "name" => "Slim Fit Chinos", "price_cents" => 4990, "needs_confirmation" => true }
    ])
    expect(batch.source_file).not_to be_attached
    expect(vision_calls.sole).to include(prompt: Receipts::Prompts::VISION, images_in: 1, user_id: user.id)
  end

  it "broadcasts the review to the owner's wardrobe stream" do
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { run }
    expect(streams.sole["target"]).to eq("intake_batch_#{batch.id}")
    expect(streams.sole.at("template").inner_html).to include("Oxford Shirt", "Add selected")
  end

  it "fails with a message when the receipt has no clothing items" do
    Ai::Client::Fake.stub(:receipt_extraction, { "items" => [] })
    run
    expect(batch).to have_attributes(status: "failed", error: "We couldn't find any clothing items on that receipt.")
    expect(batch.source_file).not_to be_attached
  end

  it "retries temporary AI failures three times, then fails" do
    Ai::Client::Fake.stub(:receipt_extraction, Ai::TransientError.new("503"))
    run
    expect(vision_calls.size).to eq(3)
    expect(batch).to have_attributes(status: "failed", error: "We couldn't read that receipt right now. Please try again.")
  end

  it "fails cleanly on a malformed response and on the daily limit" do
    Ai::Client::Fake.stub(:receipt_extraction, { "nope" => true })
    run
    expect(batch.error).to eq("We couldn't read that receipt right now. Please try again.")
  end

  it "explains the daily limit" do
    Ai::Client::Fake.stub(:receipt_extraction, Ai::QuotaExceededError.new("limit"))
    run
    expect(batch.error).to eq("You've reached today's receipt reading limit. Please try again tomorrow.")
  end

  it "fails without an AI call when the stored image cannot be read" do
    batch.source_file.attach(io: StringIO.new("not an image"), filename: "x.jpg", content_type: "image/jpeg")
    run
    expect(batch.error).to eq("We couldn't read that image. Please upload a receipt photo, screenshot or PDF.")
    expect(vision_calls).to be_empty
  end

  it "does nothing for a finished batch, and ends quietly for a removed one" do
    batch.update!(status: "ready")
    run
    expect(vision_calls).to be_empty

    gone = batch.id
    batch.destroy!
    expect { described_class.perform_now(gone) }.not_to raise_error
  end

  it "prepares a larger image than photo intake so small print stays legible" do
    allow(Wardrobe::PhotoIntake::ImagePreparer).to receive(:call).and_call_original
    run
    expect(Wardrobe::PhotoIntake::ImagePreparer).to have_received(:call).with(kind_of(String), max_side: 2400)
  end
end
