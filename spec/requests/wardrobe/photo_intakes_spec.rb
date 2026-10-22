# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Photo intake", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :onboarded) }
  let(:photo) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/outfit.jpg"), "image/jpeg") }

  before { sign_in user }

  def ready_batch(owner: user, drafts: 2)
    batch = create(:intake_batch, user: owner, status: "ready")
    drafts.times do |i|
      create(:garment_draft, :ready, intake_batch: batch, position: i,
                                     attrs: { "name" => "Item #{i}", "category" => "top", "color_primary" => "blue" })
    end
    batch
  end

  def attach_image(draft)
    draft.image.attach(io: File.open(Rails.root.join("spec/fixtures/files/garment.jpg")), filename: "d.jpg",
                       content_type: "image/jpeg")
  end

  describe "upload (POST /wardrobe/photo_intakes)" do
    it "creates a processing photo batch with the photo and queues the analysis" do
      expect { post wardrobe_photo_intakes_path, params: { photo: photo } }
        .to change(user.intake_batches, :count).by(1).and have_enqueued_job(Wardrobe::ExtractGarmentsJob)
      batch = user.intake_batches.last
      expect(batch).to have_attributes(kind: "photo", status: "processing")
      expect(batch.source_file).to be_attached
      expect(response).to redirect_to(wardrobe_photo_intake_path(batch))
    end

    it "rejects a file over 15 MB" do
      big = Tempfile.new([ "big", ".jpg" ]).tap { _1.binmode; _1.write("\xFF\xD8\xFF".b + ("0" * 16.megabytes)); _1.rewind }
      post wardrobe_photo_intakes_path, params: { photo: Rack::Test::UploadedFile.new(big.path, "image/jpeg") }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Image too large")
      expect(IntakeBatch.count).to eq(0)
    end

    it "rejects a file that is not an image, whatever its name and Content-Type say" do
      fake = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/not_an_image.txt"), "image/jpeg",
                                          original_filename: "photo.jpg")
      post wardrobe_photo_intakes_path, params: { photo: fake }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Please upload a JPEG, PNG, WebP or HEIC image")
      expect(IntakeBatch.count).to eq(0)
    end

    it "rejects an empty file and a missing file" do
      empty = Tempfile.new([ "empty", ".jpg" ])
      post wardrobe_photo_intakes_path, params: { photo: Rack::Test::UploadedFile.new(empty.path, "image/jpeg") }
      expect(response.body).to include("Uploaded file is empty")
      post wardrobe_photo_intakes_path
      expect(response.body).to include("Choose a photo to upload")
      expect(IntakeBatch.count).to eq(0)
    end

    it "is not available when the photo_intake feature is off" do
      allow(Feature).to receive(:enabled?).and_call_original
      allow(Feature).to receive(:enabled?).with(:photo_intake).and_return(false)
      post wardrobe_photo_intakes_path, params: { photo: photo }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /wardrobe/photo_intakes/:id" do
    it "shows the scanning card while processing" do
      batch = create(:intake_batch, user: user, status: "processing")
      get wardrobe_photo_intake_path(batch)
      expect(response.body).to include("Scanning your photo", 'turbo-frame id="photo_intake"')
    end

    it "shows the review with low-confidence flags when ready" do
      batch = ready_batch
      batch.garment_drafts.first.update!(attrs: batch.garment_drafts.first.attrs.merge("needs_confirmation" => true))
      get wardrobe_photo_intake_path(batch)
      expect(Nokogiri::HTML5(response.body).css("article.garment-draft").size).to eq(2)
      expect(response.body).to include("Please double-check", "Add selected")
    end

    it "shows the error and Try again when failed" do
      batch = create(:intake_batch, :failed, user: user)
      get wardrobe_photo_intake_path(batch)
      expect(response.body).to include("We couldn&#39;t analyze that photo right now. Please try again.", "Try again")
    end

    it "returns 404 for another user's batch" do
      get wardrobe_photo_intake_path(ready_batch(owner: create(:user)))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "commit (POST /wardrobe/intake_batches/:id/commit)" do
    it "adds the selected drafts as photo garments, with edits, and reports the count" do
      batch = ready_batch
      first, second = batch.garment_drafts.ordered
      post commit_wardrobe_intake_batch_path(batch), params: { drafts: {
        first.id => { selected: "1", name: "Cream Sweater", category: "top" },
        second.id => { selected: "0", name: "Item 1", category: "bottom" }
      } }

      expect(response).to redirect_to(wardrobe_path)
      expect(flash[:notice]).to eq("1 item added")
      expect(user.garments.pluck(:name, :source)).to eq([ [ "Cream Sweater", "photo" ] ])
      expect(first.reload).to be_committed
      expect(second.reload).to have_attributes(status: "ready", selected: false)
    end

    it "never creates a garment twice when committed again" do
      batch = ready_batch
      2.times { post commit_wardrobe_intake_batch_path(batch) }
      expect(user.garments.count).to eq(2)
      expect(flash[:notice]).to eq("No new items to add.")
    end

    it "moves the draft image to the garment, so discarding the batch keeps it" do
      batch = ready_batch(drafts: 1)
      draft = batch.garment_drafts.first
      attach_image(draft)
      blob = draft.image.blob

      post commit_wardrobe_intake_batch_path(batch)
      garment = user.garments.last
      expect(garment.image.blob).to eq(blob)
      expect(garment.image_status).to eq("ready")
      expect(draft.reload.image).not_to be_attached

      perform_enqueued_jobs { delete wardrobe_intake_batch_path(batch) }
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(garment.reload.image.download).to be_present
    end

    it "gives a draft still generating its image a pending garment, remembered on the draft, with a delayed safety net" do
      batch = ready_batch(drafts: 1)
      draft = batch.garment_drafts.first
      draft.update!(status: "pending")
      freeze_time do
        expect { post commit_wardrobe_intake_batch_path(batch) }
          .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).at(10.minutes.from_now)
      end
      garment = user.garments.last
      expect(garment.image_status).to eq("pending")
      expect(draft.reload.attrs["garment_id"]).to eq(garment.id)
    end

    it "keeps the placeholder for a draft whose image failed" do
      batch = ready_batch(drafts: 1)
      batch.garment_drafts.first.update!(error: "Product image unavailable")
      post commit_wardrobe_intake_batch_path(batch)
      expect(user.garments.last.image_status).to eq("placeholder")
    end

    it "commits nothing and shows the error when an edited name is invalid" do
      batch = ready_batch
      post commit_wardrobe_intake_batch_path(batch), params: { drafts: { batch.garment_drafts.first.id => { name: "" } } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank")
      expect(user.garments).to be_empty
      expect(batch.garment_drafts.reload.map(&:status)).to all(eq("ready"))
    end

    it "ignores edits for drafts of other batches" do
      other_draft = ready_batch(owner: create(:user), drafts: 1).garment_drafts.first
      post commit_wardrobe_intake_batch_path(ready_batch), params: { drafts: { other_draft.id => { name: "Hijacked" } } }
      expect(other_draft.reload.name).to eq("Item 0")
    end

    it "does not commit a batch that is still processing" do
      batch = create(:intake_batch, user: user, status: "processing")
      post commit_wardrobe_intake_batch_path(batch)
      expect(response).to redirect_to(wardrobe_photo_intake_path(batch))
      expect(user.garments).to be_empty
    end

    it "returns 404 for another user's batch" do
      batch = ready_batch(owner: create(:user))
      expect { post commit_wardrobe_intake_batch_path(batch) }.not_to change(Garment, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "discard (DELETE /wardrobe/intake_batches/:id)" do
    it "deletes the batch and its drafts" do
      batch = ready_batch
      expect { delete wardrobe_intake_batch_path(batch) }.to change(GarmentDraft, :count).by(-2)
      expect(IntakeBatch.exists?(batch.id)).to be(false)
      expect(response).to redirect_to(new_wardrobe_photo_intake_path)
    end

    it "returns 404 for another user's batch" do
      batch = ready_batch(owner: create(:user))
      delete wardrobe_intake_batch_path(batch)
      expect(response).to have_http_status(:not_found)
      expect(IntakeBatch.exists?(batch.id)).to be(true)
    end
  end

  describe "PATCH /wardrobe/drafts/:id" do
    it "updates selection, name and category" do
      draft = ready_batch.garment_drafts.first
      patch wardrobe_draft_path(draft), params: { draft: { selected: "0", name: " Blue  Jeans ", category: "bottom" } },
                                        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(draft.reload).to have_attributes(selected: false, name: "Blue Jeans", category: "bottom")
      expect(response.body).to include(%(target="garment_draft_#{draft.id}"))
    end

    it "refuses a committed draft" do
      draft = ready_batch.garment_drafts.first
      draft.update!(status: "committed")
      patch wardrobe_draft_path(draft), params: { draft: { name: "Changed" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for another user's draft" do
      draft = ready_batch(owner: create(:user)).garment_drafts.first
      original_name = draft.name
      patch wardrobe_draft_path(draft), params: { draft: { name: "Hijacked" } }
      expect(response).to have_http_status(:not_found)
      expect(draft.reload.name).to eq(original_name)
    end
  end
end
