# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::ExtractGarmentsJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch) do
    create(:intake_batch, user: user, status: "processing").tap do |b|
      b.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "outfit.jpg",
                           content_type: "image/jpeg")
    end
  end

  def extraction_calls = Ai::Client::Fake.calls.select { _1[:kind] == "garment_extraction" }

  def run
    perform_enqueued_jobs(only: [ described_class, ActiveStorage::PurgeJob ]) { described_class.perform_later(batch.id) }
    batch.reload
  end

  it "runs on the ai_text queue" do
    expect(described_class.new.queue_name).to eq("ai_text")
  end

  it "creates drafts from the AI's items, marks the batch ready and queues one image job per draft" do
    expect { run }.to have_enqueued_job(Wardrobe::GenerateDraftImageJob).exactly(2).times

    expect(batch).to have_attributes(status: "ready", progress: 30, error: nil)
    drafts = batch.garment_drafts.ordered
    expect(drafts.map(&:name)).to eq([ "Crewneck Sweater", "Straight Jeans" ]) # spec/fixtures/ai/garment_extraction.json
    expect(drafts.map(&:status)).to all(eq("pending"))
    expect(drafts.map(&:user)).to all(eq(user))
  end

  it "sends the exact prompt, the schema and the photo as one JPEG image for the batch owner" do
    run
    expect(extraction_calls.size).to eq(1)
    expect(extraction_calls.first).to include(method: :generate_json, prompt: Wardrobe::PhotoIntake::Prompts::EXTRACTION,
                                              images_in: 1, user_id: user.id)
  end

  it "deletes the uploaded photo after analysis" do
    run
    expect(batch.source_file).not_to be_attached
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "broadcasts the review to the owner's wardrobe stream" do
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { run }
    review = streams.find { _1["target"] == "intake_batch_#{batch.id}" }
    expect(review["action"]).to eq("replace")
    expect(review.at("template").inner_html).to include("Crewneck Sweater", "Add selected")
  end

  it "does nothing for a batch that already finished" do
    batch.update!(status: "ready")
    run
    expect(extraction_calls).to be_empty
  end

  describe "failures (design doc 6.6 errors)" do
    it "fails with the no-garments message when nothing is detected" do
      Ai::Client::Fake.stub(:garment_extraction, { "items" => [] })
      run
      expect(batch).to have_attributes(status: "failed",
                                       error: "No garments detected from image. Please upload a clearer outfit photo.")
      expect(batch.source_file).not_to be_attached
    end

    it "retries a temporary AI failure three times, then fails with the try-again message" do
      Ai::Client::Fake.stub(:garment_extraction, Ai::TransientError.new("503"))
      run
      expect(extraction_calls.size).to eq(3)
      expect(batch).to have_attributes(status: "failed", error: "We couldn't analyze that photo right now. Please try again.")
      expect(batch.source_file).not_to be_attached
    end

    it "keeps the photo while a retry is still to come" do
      Ai::Client::Fake.stub(:garment_extraction, Ai::TransientError.new("503"))
      described_class.perform_now(batch.id)
      expect(batch.reload.source_file).to be_attached
      expect(batch.status).to eq("processing")
    end

    it "fails cleanly on a malformed response" do
      Ai::Client::Fake.stub(:garment_extraction, { "kind" => "garment_extraction" })
      run
      expect(batch).to have_attributes(status: "failed", error: "We couldn't analyze that photo right now. Please try again.")
    end

    it "fails cleanly when the safety filter blocks the photo" do
      Ai::Client::Fake.stub(:garment_extraction, Ai::ContentBlockedError.new("blocked"))
      run
      expect(batch.status).to eq("failed")
    end

    it "explains the daily limit" do
      Ai::Client::Fake.stub(:garment_extraction, Ai::QuotaExceededError.new("limit"))
      run
      expect(batch.error).to eq("You've reached today's photo analysis limit. Please try again tomorrow.")
    end

    it "fails without calling the AI when the stored photo cannot be read" do
      batch.source_file.attach(io: StringIO.new("not an image"), filename: "x.jpg", content_type: "image/jpeg")
      run
      expect(batch.error).to eq("We couldn't read that photo. Please upload a JPEG, PNG, WebP or HEIC image.")
      expect(extraction_calls).to be_empty
    end

    it "fails and re-raises an unexpected error, so it shows in the job queue" do
      allow(Wardrobe::PhotoIntake::Mapper).to receive(:call).and_raise(RuntimeError, "boom")
      expect { described_class.perform_now(batch.id) }.to raise_error(RuntimeError, "boom")
      expect(batch.reload.status).to eq("failed")
    end

    it "broadcasts the failure with a Try again button" do
      Ai::Client::Fake.stub(:garment_extraction, { "items" => [] })
      streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { run }
      expect(streams.first.at("template").inner_html).to include("No garments detected", "Try again")
    end
  end

  it "is discarded for a deleted batch" do
    id = batch.id
    batch.destroy!
    expect { described_class.perform_now(id) }.not_to raise_error
  end
end
