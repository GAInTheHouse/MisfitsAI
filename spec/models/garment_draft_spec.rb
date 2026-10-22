# frozen_string_literal: true

require "rails_helper"

RSpec.describe GarmentDraft do
  let(:batch) { create(:intake_batch) }

  describe "associations" do
    it { is_expected.to belong_to(:intake_batch) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one_attached(:image) }
  end

  describe "defaults" do
    subject(:draft) { described_class.new }

    it "starts pending, selected and with empty attrs" do
      expect(draft.status).to eq("pending")
      expect(draft.selected).to be(true)
      expect(draft.attrs).to eq({})
    end
  end

  describe "attrs column (G6 migration)" do
    it "defaults to {} in the database when a row is inserted without attrs" do
      described_class.insert!({ intake_batch_id: batch.id, user_id: batch.user_id, status: "pending" })
      expect(described_class.last.attrs).to eq({})
    end

    it "still rejects NULL" do
      expect {
        described_class.insert!({ intake_batch_id: batch.id, user_id: batch.user_id, status: "pending", attrs: nil })
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "validations" do
    subject { build(:garment_draft, intake_batch: batch) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }

    it "requires attrs to be a hash" do
      draft = build(:garment_draft, intake_batch: batch, attrs: [ "not", "a", "hash" ])
      expect(draft).not_to be_valid
      expect(draft.errors[:attrs]).to include("must be a hash")
    end

    it "requires the draft's user to own its intake batch" do
      draft = build(:garment_draft, intake_batch: batch, user: create(:user))
      expect(draft).not_to be_valid
      expect(draft.errors[:user]).to include("must own the intake batch")
    end

    it "is valid when the user owns the batch" do
      expect(build(:garment_draft, intake_batch: batch)).to be_valid
    end
  end

  describe "scopes" do
    it ".ordered sorts by position" do
      second = create(:garment_draft, intake_batch: batch, position: 2)
      first = create(:garment_draft, intake_batch: batch, position: 1)
      expect(batch.garment_drafts.ordered).to eq([ first, second ])
    end

    it ".committable keeps selected drafts that are pending or ready" do
      pending_draft = create(:garment_draft, intake_batch: batch)
      ready_draft = create(:garment_draft, :ready, intake_batch: batch)
      create(:garment_draft, :ready, intake_batch: batch, selected: false)
      create(:garment_draft, :failed, intake_batch: batch)
      create(:garment_draft, intake_batch: batch, status: "committed")
      create(:garment_draft, intake_batch: batch, status: "discarded")

      expect(batch.garment_drafts.committable).to contain_exactly(pending_draft, ready_draft)
    end

    it ".stale returns uncommitted drafts older than 24 hours (design doc 5.3)" do
      now = Time.zone.parse("2026-10-21 12:00")
      old = create(:garment_draft, intake_batch: batch, created_at: now - 25.hours)
      create(:garment_draft, intake_batch: batch, created_at: now - 25.hours, status: "committed")
      create(:garment_draft, intake_batch: batch, created_at: now - 23.hours)

      expect(described_class.stale(now)).to contain_exactly(old)
    end
  end

  describe "status predicates" do
    it "has one predicate per status" do
      draft = build(:garment_draft, intake_batch: batch, status: "ready")
      expect(draft).to be_ready
      expect(draft).not_to be_pending
      expect(described_class::STATUSES.map { draft.respond_to?(:"#{_1}?") }).to all(be(true))
    end
  end

  describe "attrs readers" do
    let(:draft) do
      build(:garment_draft, intake_batch: batch, attrs: {
        "name" => "Oxford Shirt", "category" => "top", "color_primary" => "white", "brand" => "",
        "price_cents" => 3990, "pattern" => nil, "confidence" => 0.62, "needs_confirmation" => true,
        "source_line" => "Oxford Shirt White M $39.90"
      })
    end

    it "reads name and category" do
      expect([ draft.name, draft.category ]).to eq(%w[Oxford\ Shirt top])
    end

    it "returns only garment columns, without blanks, for committing" do
      expect(draft.garment_attributes).to eq(
        "name" => "Oxford Shirt", "category" => "top", "color_primary" => "white", "price_cents" => 3990
      )
    end

    it "reads receipt confidence and the review flag" do
      expect(draft.confidence).to eq(0.62)
      expect(draft.needs_confirmation?).to be(true)
    end

    it "treats a missing review flag as false" do
      expect(build(:garment_draft, intake_batch: batch, attrs: {}).needs_confirmation?).to be(false)
      expect(build(:garment_draft, intake_batch: batch, attrs: {}).confidence).to be_nil
    end
  end

  describe "#committable?" do
    it "matches the committable scope rules" do
      expect(build(:garment_draft, intake_batch: batch, status: "ready")).to be_committable
      expect(build(:garment_draft, intake_batch: batch, status: "pending")).to be_committable
      expect(build(:garment_draft, intake_batch: batch, status: "ready", selected: false)).not_to be_committable
      expect(build(:garment_draft, intake_batch: batch, status: "failed")).not_to be_committable
      expect(build(:garment_draft, intake_batch: batch, status: "committed")).not_to be_committable
    end
  end
end
