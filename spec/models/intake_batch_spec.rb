# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntakeBatch do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:garment_drafts).dependent(:destroy) }
    it { is_expected.to have_one_attached(:source_file) }
  end

  describe "defaults" do
    subject(:batch) { described_class.new }

    it "starts pending at 0% progress" do
      expect(batch.status).to eq("pending")
      expect(batch.progress).to eq(0)
    end
  end

  describe "validations" do
    subject { build(:intake_batch) }

    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { is_expected.to validate_numericality_of(:progress).only_integer.is_in(0..100) }
    it { is_expected.to validate_inclusion_of(:parser_strategy).in_array(described_class::PARSER_STRATEGIES).allow_nil }
  end

  describe "extracted_text_preview (design doc 6.12)" do
    it "keeps text of up to 600 characters as is" do
      text = "a" * 600
      expect(build(:intake_batch, :receipt, extracted_text_preview: text).extracted_text_preview).to eq(text)
    end

    it "keeps the first 600 characters and appends ... when longer" do
      batch = build(:intake_batch, :receipt, extracted_text_preview: ("b" * 600) + "TAIL")
      expect(batch.extracted_text_preview).to eq(("b" * 600) + "...")
    end

    it "leaves nil alone" do
      expect(build(:intake_batch, extracted_text_preview: nil).extracted_text_preview).to be_nil
    end
  end

  describe "scopes" do
    it ".photos and .receipts filter by kind" do
      photo = create(:intake_batch)
      receipt = create(:intake_batch, :receipt)
      expect(described_class.photos).to contain_exactly(photo)
      expect(described_class.receipts).to contain_exactly(receipt)
    end

    it ".stale returns batches with no activity (updated_at) for more than 24 hours" do
      now = Time.zone.parse("2026-10-21 12:00")
      idle = create(:intake_batch, created_at: now - 3.days, updated_at: now - 25.hours)
      create(:intake_batch, created_at: now - 3.days, updated_at: now - 1.hour) # old but still active
      create(:intake_batch, created_at: now - 1.hour, updated_at: now - 1.hour)
      expect(described_class.stale(now)).to contain_exactly(idle)
    end
  end

  describe "predicates" do
    it "has kind and status predicates" do
      batch = build(:intake_batch, :receipt, status: "processing")
      expect(batch).to be_receipt
      expect(batch).not_to be_photo
      expect(batch).to be_processing
      expect(batch).not_to be_finished
    end

    it "is finished when ready or failed" do
      expect(build(:intake_batch, :ready)).to be_finished
      expect(build(:intake_batch, :failed)).to be_finished
      expect(build(:intake_batch, status: "pending")).not_to be_finished
    end
  end

  describe "status transitions" do
    let(:batch) { create(:intake_batch, status: "pending") }

    it "#mark_processing! sets processing, progress and clears the error" do
      batch.update!(error: "old")
      batch.mark_processing!(progress: 40)
      expect(batch.reload).to have_attributes(status: "processing", progress: 40, error: nil)
    end

    it "#mark_ready! completes the batch" do
      batch.mark_ready!
      expect(batch.reload).to have_attributes(status: "ready", progress: 100, error: nil)
    end

    it "#mark_failed! stores the user-facing message" do
      batch.mark_failed!("No garments detected from image. Please upload a clearer outfit photo.")
      expect(batch.reload).to have_attributes(
        status: "failed", error: "No garments detected from image. Please upload a clearer outfit photo."
      )
    end
  end

  it "destroys its drafts with it" do
    batch = create(:intake_batch)
    create_list(:garment_draft, 2, intake_batch: batch)
    expect { batch.destroy! }.to change(GarmentDraft, :count).by(-2)
  end
end
