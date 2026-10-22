# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::GenerateDraftImageJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:batch) { create(:intake_batch, user: user, status: "ready", progress: 30) }
  let(:draft) do
    create(:garment_draft, intake_batch: batch, attrs: { "name" => "Straight Jeans", "item_type" => "straight jeans",
                                                         "category" => "bottom", "color_primary" => "blue" })
  end

  def image_calls = Ai::Client::Fake.calls.select { _1[:method] == :generate_image }

  it "attaches a product image with the draft prompt and marks the draft ready" do
    described_class.perform_now(draft.id)
    draft.reload
    expect(draft).to be_ready
    expect(draft.image).to be_attached
    expect(image_calls.first).to include(kind: "garment_image", user_id: user.id,
                                         prompt: Wardrobe::PhotoIntake::Prompts.product_image(draft.attrs))
  end

  it "moves the batch progress towards 100" do
    other = create(:garment_draft, intake_batch: batch)
    described_class.perform_now(draft.id)
    expect(batch.reload.progress).to eq(65)
    described_class.perform_now(other.id)
    expect(batch.reload.progress).to eq(100)
  end

  it "broadcasts only the image area and the progress, never the editable fields" do
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(draft.id) }
    expect(streams.map { _1["target"] }).to contain_exactly("image_garment_draft_#{draft.id}", "progress_intake_batch_#{batch.id}")
  end

  [ Ai::ContentBlockedError.new("x"), Ai::QuotaExceededError.new("x"), Ai::DisabledError.new("x") ].each do |error|
    it "leaves a committable draft with the placeholder on #{error.class.name.demodulize}" do
      Ai::Client::Fake.stub(:garment_image, error)
      described_class.perform_now(draft.id)
      expect(draft.reload).to have_attributes(status: "ready", error: "Product image unavailable")
      expect(draft.image).not_to be_attached
      expect(draft).to be_committable
    end
  end

  it "retries temporary failures three times, then leaves the placeholder" do
    Ai::Client::Fake.stub(:garment_image, Ai::TransientError.new("503"))
    perform_enqueued_jobs { described_class.perform_later(draft.id) }
    expect(image_calls.size).to eq(3)
    expect(draft.reload).to have_attributes(status: "ready", error: "Product image unavailable")
  end

  it "makes no AI call for a draft that was committed or discarded meanwhile" do
    draft.update!(status: "committed")
    described_class.perform_now(draft.id)
    expect(image_calls).to be_empty
    expect(draft.reload).to be_committed
  end

  it "does not attach to a draft committed while the AI call was in flight" do
    client = Ai::Client::Fake.new
    allow(Ai::Client).to receive(:current).and_return(client)
    allow(client).to receive(:generate_image).and_wrap_original do |original, **kwargs|
      GarmentDraft.find(draft.id).update!(status: "committed")
      original.call(**kwargs)
    end
    described_class.perform_now(draft.id)
    expect(draft.reload.image).not_to be_attached
    expect(draft).to be_committed
  end

  describe "a draft committed before its image is done (one AI call serves both)" do
    def committed_garment
      draft # create the pending draft before committing the batch
      Wardrobe::PhotoIntake::Commit.call(batch: batch).first
    end

    it "gives the image to the garment when the job runs after the commit" do
      garment = committed_garment
      expect(garment.image_status).to eq("pending")

      described_class.perform_now(draft.id)

      expect(garment.reload).to have_attributes(image_status: "ready")
      expect(garment.image).to be_attached
      expect(draft.reload.image).not_to be_attached
      expect(image_calls.size).to eq(1)
    end

    it "hands over an image whose AI call was in flight during the commit" do
      client = Ai::Client::Fake.new
      allow(Ai::Client).to receive(:current).and_return(client)
      garment = nil
      allow(client).to receive(:generate_image).and_wrap_original do |original, **kwargs|
        garment = committed_garment # the user commits while this call runs
        original.call(**kwargs)
      end

      described_class.perform_now(draft.id)

      expect(garment.reload.image).to be_attached
      expect(garment.image_status).to eq("ready")
      expect(client).to have_received(:generate_image).once
    end

    it "leaves the delayed safety-net job nothing to do, so there is no second AI call" do
      garment = committed_garment
      described_class.perform_now(draft.id)
      Wardrobe::GenerateGarmentImageJob.perform_now(garment.id)
      expect(image_calls.size).to eq(1)
    end

    it "lets the safety net make the image when the draft job never delivers (e.g. the draft was purged)" do
      garment = committed_garment
      batch.destroy!
      described_class.perform_now(draft.id) # discarded: the draft is gone
      Wardrobe::GenerateGarmentImageJob.perform_now(garment.id)
      expect(garment.reload.image_status).to eq("ready")
      expect(image_calls.size).to eq(1)
    end

    it "makes no AI call when the garment no longer waits for an image" do
      garment = committed_garment
      garment.update!(image_status: "placeholder")
      described_class.perform_now(draft.id)
      expect(image_calls).to be_empty
    end

    it "broadcasts the garment card and thumbnail" do
      garment = committed_garment
      streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) { described_class.perform_now(draft.id) }
      expect(streams.map { _1["target"] }).to include("garment_#{garment.id}", "thumb_garment_#{garment.id}")
    end
  end

  it "allows one run per draft" do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.new(draft.id).concurrency_key).to include("draft-image-#{draft.id}")
  end
end
