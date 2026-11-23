# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avatars::OutfitPreviewJob, type: :job do
  let(:user) { create(:user, :onboarded) }
  let(:plan) { create(:week_plan, user:) }
  let(:top) { create(:garment, :top, :with_image, user:) }
  let(:bottom) { create(:garment, :bottom, :with_image, user:) }
  let!(:rec) do
    create(:outfit_recommendation, week_plan: plan, top:, bottom:, preview_status: "pending")
  end

  before do
    user.profile.avatar.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/garment.jpg")),
      filename: "avatar.jpg",
      content_type: "image/jpeg"
    )
  end

  it "builds a collage preview when AI image generation is disabled" do
    ClimateControl.modify AI_IMAGE_GEN_ENABLED: "false" do
      described_class.perform_now(rec.id)
    end

    rec.reload
    expect(rec.preview_status).to eq("ready")
    expect(rec.preview_strategy).to eq("collage")
    expect(rec.preview_image).to be_attached
  end

  it "reuses a ready preview when the cache key still matches" do
    allow(Avatars::OutfitCollage).to receive(:build).and_call_original

    ClimateControl.modify AI_IMAGE_GEN_ENABLED: "false" do
      described_class.perform_now(rec.id)
      described_class.perform_now(rec.id)
    end

    expect(Avatars::OutfitCollage).to have_received(:build).once
    expect(rec.reload.preview_strategy).to eq("collage")
  end
end
