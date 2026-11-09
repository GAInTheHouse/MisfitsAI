# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authorization", type: :request do
  let(:user_a) { create(:user, :onboarded) }
  let(:user_b) { create(:user, :onboarded) }
  let!(:garment) { create(:garment, user: user_a) }

  before { sign_in user_b }

  it "returns 404 for another user's garment edit" do
    get edit_garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for hide" do
    patch hide_garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for destroy" do
    delete garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  # Phase 2 (design doc 8.4: each phase adds a case for every route it builds).
  it "returns 404 for retry_image" do
    post retry_image_garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  it "does not show another user's garments on the wardrobe page" do
    get wardrobe_path
    expect(response.body).not_to include(garment.name)
  end

  describe "photo intake (Phase 2)" do
    let(:batch) { create(:intake_batch, user: user_a, status: "ready") }
    let!(:draft) { create(:garment_draft, :ready, intake_batch: batch) }

    it "returns 404 for another user's batch, commit, discard and draft" do
      get wardrobe_photo_intake_path(batch)
      expect(response).to have_http_status(:not_found)
      post commit_wardrobe_intake_batch_path(batch)
      expect(response).to have_http_status(:not_found)
      delete wardrobe_intake_batch_path(batch)
      expect(response).to have_http_status(:not_found)
      patch wardrobe_draft_path(draft), params: { draft: { name: "Hijacked" } }
      expect(response).to have_http_status(:not_found)

      expect(user_b.garments).to be_empty
      expect(batch.reload.garment_drafts.first.name).not_to eq("Hijacked")
    end
  end

  describe "planner (Phase 3)" do
    let(:plan) { create(:week_plan, user: user_a) }
    let!(:event) { create(:week_event, week_plan: plan) }

    it "returns 404 for another user's week event update" do
      patch week_plan_event_path(event), params: { week_event: { event_type: "gym" } }
      expect(response).to have_http_status(:not_found)
    end

  end

  describe "receipts (Phase 2)" do
    let(:receipt) { create(:intake_batch, :receipt, user: user_a, status: "ready") }
    let!(:row) { create(:garment_draft, :ready, intake_batch: receipt) }

    it "returns 404 for another user's receipt, its commit and discard" do
      get wardrobe_receipt_path(receipt)
      expect(response).to have_http_status(:not_found)
      post commit_wardrobe_intake_batch_path(receipt)
      expect(response).to have_http_status(:not_found)
      delete wardrobe_intake_batch_path(receipt)
      expect(response).to have_http_status(:not_found)
      expect(user_b.garments).to be_empty
      expect(IntakeBatch.exists?(receipt.id)).to be(true)
    end

    it "cannot open a photo batch through the receipt page, or a receipt through the photo page" do
      photo = create(:intake_batch, user: user_b, status: "ready")
      own_receipt = create(:intake_batch, :receipt, user: user_b, status: "ready")
      get wardrobe_receipt_path(photo)
      expect(response).to have_http_status(:not_found)
      get wardrobe_photo_intake_path(own_receipt)
      expect(response).to have_http_status(:not_found)
    end
  end
end
