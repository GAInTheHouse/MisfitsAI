# frozen_string_literal: true

require "rails_helper"
require "vips"

RSpec.describe Wardrobe::GenerateGarmentImageJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:garment) { create(:garment, user: user, name: "White Oxford Shirt", category: "top", image_status: "pending") }

  def image_calls
    Ai::Client::Fake.calls.select { _1[:method] == :generate_image }
  end

  def dimensions(attachment)
    image = Vips::Image.new_from_buffer(attachment.download, "")
    [ image.width, image.height ]
  end

  it "runs on the ai_images queue (one Imagen call at a time in production)" do
    expect(described_class.new.queue_name).to eq("ai_images")
  end

  describe "success" do
    it "attaches a 512x512 JPEG product image and marks the garment ready" do
      described_class.perform_now(garment.id)

      garment.reload
      expect(garment.image_status).to eq("ready")
      expect(garment.image).to be_attached
      expect(garment.image.content_type).to eq("image/jpeg")
      expect(dimensions(garment.image)).to eq([ 512, 512 ])
    end

    it "asks the AI for a garment_image with the design doc prompt, on behalf of the owner" do
      described_class.perform_now(garment.id)

      expect(image_calls.size).to eq(1)
      expect(image_calls.first).to include(kind: "garment_image", user_id: user.id,
                                           prompt: Wardrobe::Prompts.garment_image(garment))
    end

    it "logs the call in ai_calls through Ai::Client" do
      expect { described_class.perform_now(garment.id) }.to change { AiCall.where(kind: "garment_image").count }.by(1)
    end

    it "honours GARMENT_ASSET_SIZE" do
      with_env("GARMENT_ASSET_SIZE" => "128") { described_class.perform_now(garment.id) }
      expect(dimensions(garment.reload.image)).to eq([ 128, 128 ])
    end

    it "broadcasts the ready card and thumbnail to the owner's wardrobe stream" do
      streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(garment.id) }

      card = streams.find { _1["target"] == "garment_#{garment.id}" }
      thumb = streams.find { _1["target"] == "thumb_garment_#{garment.id}" }
      expect(card["action"]).to eq("replace")
      expect(thumb["action"]).to eq("replace")
      expect(card.at("template").inner_html).to include(%(data-image-source="attached"))
      expect(thumb.at("template").inner_html).to include(%(src="/rails/active_storage/representations/redirect/))
    end
  end

  describe "idempotency" do
    it "does not call the AI again for a garment that already has its image" do
      described_class.perform_now(garment.id)
      expect { described_class.perform_now(garment.id) }.not_to(change { image_calls.size })
      expect(garment.reload.image_status).to eq("ready")
    end

    it "generates for a garment still on its placeholder (manual add keeps placeholder until ready)" do
      garment.update!(image_status: "placeholder")
      described_class.perform_now(garment.id)
      expect(garment.reload.image_status).to eq("ready")
    end
  end

  describe "duplicate runs" do
    it "allows only one run per garment at a time (Solid Queue concurrency control)" do
      expect(described_class.concurrency_limit).to eq(1)
      expect(described_class.new(garment.id).concurrency_key).to include("garment-image-#{garment.id}")
      expect(described_class.new(garment.id).concurrency_key)
        .not_to eq(described_class.new(create(:garment).id).concurrency_key)
    end

    it "keeps the image of a run that finished first instead of overwriting it" do
      client = Ai::Client::Fake.new
      allow(Ai::Client).to receive(:current).and_return(client)
      winner_blob = nil
      allow(client).to receive(:generate_image).and_wrap_original do |original, **kwargs|
        # While this run waits on the AI, another run for the same garment finishes and attaches its image.
        other_run = Garment.find(garment.id)
        other_run.image.attach(io: File.open(Rails.root.join("spec/fixtures/files/garment.jpg")),
                               filename: "winner.jpg", content_type: "image/jpeg")
        other_run.update!(image_status: "ready")
        winner_blob = other_run.image.blob
        original.call(**kwargs)
      end

      described_class.perform_now(garment.id)

      expect(garment.reload.image.blob).to eq(winner_blob)
      expect(garment.image_status).to eq("ready")
    end
  end

  describe "fallbacks (design doc 6.4 rule 4)" do
    it "keeps the placeholder when image generation is switched off" do
      with_env("AI_IMAGE_GEN_ENABLED" => "false") { described_class.perform_now(garment.id) }
      expect(garment.reload).to have_attributes(image_status: "placeholder")
      expect(garment.image).not_to be_attached
    end

    it "keeps the placeholder when the user is over the daily image cap" do
      with_env("AI_DAILY_IMAGE_LIMIT" => "0") { described_class.perform_now(garment.id) }
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "keeps the placeholder when the safety filter blocks the image" do
      Ai::Client::Fake.stub(:garment_image, Ai::ContentBlockedError.new("blocked"))
      described_class.perform_now(garment.id)
      expect(garment.reload.image_status).to eq("placeholder")
    end

    it "does not retry those cases" do
      Ai::Client::Fake.stub(:garment_image, Ai::ContentBlockedError.new("blocked"))
      expect { described_class.perform_now(garment.id) }.not_to have_enqueued_job(described_class)
    end

    it "broadcasts the placeholder card so a pending spinner does not stay on screen" do
      Ai::Client::Fake.stub(:garment_image, Ai::ContentBlockedError.new("blocked"))
      streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(garment.id) }
      card = streams.find { _1["target"] == "garment_#{garment.id}" }
      expect(card.at("template").inner_html).to include(%(data-image-source="placeholder"))
      expect(card.at("template").inner_html).not_to include("Creating image")
    end
  end

  describe "transient failures (429, 5xx, timeouts)" do
    before { Ai::Client::Fake.stub(:garment_image, Ai::TransientError.new("HTTP 503")) }

    it "schedules a retry" do
      expect { described_class.perform_now(garment.id) }.to have_enqueued_job(described_class).with(garment.id)
      expect(garment.reload.image_status).to eq("pending")
    end

    it "marks the garment failed after three attempts, so the card offers Retry image" do
      perform_enqueued_jobs { described_class.perform_later(garment.id) }

      expect(image_calls.size).to eq(3)
      expect(garment.reload.image_status).to eq("failed")
      expect(garment.image).not_to be_attached
    end
  end

  it "marks the garment failed and re-raises an unexpected error, so it shows up in the job queue" do
    allow(Media::ImageNormalizer).to receive(:to_square_jpeg).and_raise(RuntimeError, "vips crashed")

    expect { described_class.perform_now(garment.id) }.to raise_error(RuntimeError, "vips crashed")
    expect(garment.reload.image_status).to eq("failed")
  end

  it "is discarded quietly when the garment was deleted before it ran" do
    id = garment.id
    garment.destroy!
    expect { described_class.perform_now(id) }.not_to raise_error
    expect(image_calls).to be_empty
  end
end
