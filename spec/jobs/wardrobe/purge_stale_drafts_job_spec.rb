# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::PurgeStaleDraftsJob do
  include ActiveJob::TestHelper

  let(:now) { Time.zone.parse("2026-10-22 04:00") }
  let(:user) { create(:user) }

  def batch(idle_for:, created_ago: idle_for, status: "ready", drafts: 1)
    create(:intake_batch, user: user, status: status, created_at: now - created_ago, updated_at: now - idle_for).tap do |b|
      drafts.times { create(:garment_draft, intake_batch: b).update_columns(updated_at: now - idle_for) }
    end
  end

  it "removes batches idle for more than 24 hours, with their drafts (design doc 5.3)" do
    idle = batch(idle_for: 25.hours, drafts: 2)
    fresh = batch(idle_for: 1.hour)

    described_class.perform_now(now)

    expect(IntakeBatch.all).to contain_exactly(fresh)
    expect(GarmentDraft.where(intake_batch_id: idle.id)).to be_empty
  end

  it "keeps a batch created long ago that is still being processed" do
    active = batch(idle_for: 5.minutes, created_ago: 3.days, status: "processing")
    described_class.perform_now(now)
    expect(IntakeBatch.exists?(active.id)).to be(true)
  end

  it "applies the 24-hour rule at the boundary: exactly 24 hours idle is kept, a second more is removed" do
    edge = batch(idle_for: 24.hours)
    past = batch(idle_for: 24.hours + 1.second)
    described_class.perform_now(now)
    expect(IntakeBatch.exists?(edge.id)).to be(true)
    expect(IntakeBatch.exists?(past.id)).to be(false)
  end

  it "removes a batch stuck in processing for more than 24 hours, so nothing lingers forever" do
    stuck = batch(idle_for: 2.days, status: "processing")
    described_class.perform_now(now)
    expect(IntakeBatch.exists?(stuck.id)).to be(false)
  end

  it "keeps a batch that became active between the query and the lock" do
    revived = batch(idle_for: 25.hours)
    allow_any_instance_of(IntakeBatch).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      IntakeBatch.where(id: original.receiver.id).update_all(updated_at: now) # a job touches it right now
      original.call(*args, &block)
    end

    described_class.perform_now(now)

    expect(IntakeBatch.exists?(revived.id)).to be(true)
  end

  it "skips a batch removed by someone else meanwhile, and is harmless to run twice" do
    gone = batch(idle_for: 25.hours)
    other = batch(idle_for: 25.hours)
    allow_any_instance_of(IntakeBatch).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      IntakeBatch.find_by(id: gone.id)&.destroy! if original.receiver.id == gone.id # e.g. the user discards it
      original.call(*args, &block)
    end

    expect { described_class.perform_now(now) }.not_to raise_error
    expect { described_class.perform_now(now) }.not_to raise_error
    expect(IntakeBatch.exists?(other.id)).to be(false)
  end

  it "never removes the image of a garment committed from a purged batch" do
    committed = create(:intake_batch, user: user, status: "ready")
    draft = create(:garment_draft, :ready, intake_batch: committed, attrs: { "name" => "Coat", "category" => "outerwear" })
    draft.image.attach(io: File.open(Rails.root.join("spec/fixtures/files/garment.jpg")), filename: "c.jpg",
                       content_type: "image/jpeg")
    Wardrobe::PhotoIntake::Commit.call(batch: committed)
    committed.update_columns(updated_at: now - 2.days)

    perform_enqueued_jobs { described_class.perform_now(now) }

    expect(IntakeBatch.exists?(committed.id)).to be(false)
    expect(user.garments.first.image.download).to be_present
  end

  describe "jobs still running for a purged batch" do
    it "draft image job: stops without an AI call and recreates nothing" do
      purged = batch(idle_for: 25.hours, status: "ready")
      draft_id = purged.garment_drafts.first.id
      described_class.perform_now(now)

      expect { Wardrobe::GenerateDraftImageJob.perform_now(draft_id) }.not_to raise_error
      expect(Ai::Client::Fake.calls).to be_empty
      expect([ IntakeBatch.count, GarmentDraft.count ]).to eq([ 0, 0 ])
    end

    it "extraction job: a batch removed during the AI call ends quietly and recreates nothing" do
      purged = create(:intake_batch, user: user, status: "processing")
      purged.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "o.jpg",
                                content_type: "image/jpeg")
      client = Ai::Client::Fake.new
      allow(Ai::Client).to receive(:current).and_return(client)
      allow(client).to receive(:generate_json).and_wrap_original do |original, **kwargs|
        IntakeBatch.find(purged.id).destroy! # discarded or purged while Gemini works
        original.call(**kwargs)
      end

      expect { Wardrobe::ExtractGarmentsJob.perform_now(purged.id) }.not_to raise_error
      expect([ IntakeBatch.count, GarmentDraft.count ]).to eq([ 0, 0 ])
    end
  end

  it "is scheduled daily in production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    expect(recurring.dig("production", "purge_stale_intake_drafts", "class")).to eq("Wardrobe::PurgeStaleDraftsJob")
  end
end
