# frozen_string_literal: true

require "rails_helper"

# Phase 2 Step 9: security and reliability regressions.
RSpec.describe "Phase 2 security and reliability", type: :request do
  include ActiveJob::TestHelper

  let(:owner) { create(:user, :onboarded) }
  let(:intruder) { create(:user, :onboarded) }
  let(:photo) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/outfit.jpg"), "image/jpeg") }

  describe "Active Storage direct uploads (unauthenticated blob creation)" do
    let(:blob_params) do
      { blob: { filename: "x.jpg", byte_size: 5, checksum: Digest::MD5.base64digest("hello"), content_type: "image/jpeg" } }
    end

    it "is not available signed out" do
      post "/rails/active_storage/direct_uploads", params: blob_params, as: :json
      expect(response).to have_http_status(:not_found)
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "is not available signed in either (the app never uses it)" do
      sign_in owner
      post "/rails/active_storage/direct_uploads", params: blob_params, as: :json
      expect(response).to have_http_status(:not_found)
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "is not used by any upload form, so blocking it cannot break photo, receipt or garment uploads" do
      sign_in owner
      [ wardrobe_path, new_wardrobe_photo_intake_path, new_wardrobe_receipt_path, new_garment_path ].each do |path|
        get path
        expect(response.body).not_to include("direct_upload", "direct-upload")
      end
    end

    it "still serves blobs through the redirect routes" do
      garment = create(:garment, :with_image, user: owner)
      get Rails.application.routes.url_helpers.rails_blob_path(garment.image, only_path: true)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "authorization sweep over Phase 2 member routes (design doc 8.4)" do
    let(:garment) { create(:garment, user: owner) }
    let(:photo_batch) { create(:intake_batch, user: owner, status: "ready").tap { create(:garment_draft, :ready, intake_batch: _1) } }
    let(:receipt_batch) { create(:intake_batch, :receipt, user: owner, status: "ready").tap { create(:garment_draft, :ready, intake_batch: _1) } }

    before { sign_in intruder }

    {
      "edit a garment" => ->(s) { [ :get, s.edit_garment_path(s.garment) ] },
      "update a garment" => ->(s) { [ :patch, s.garment_path(s.garment) ] },
      "delete a garment" => ->(s) { [ :delete, s.garment_path(s.garment) ] },
      "hide a garment" => ->(s) { [ :patch, s.hide_garment_path(s.garment) ] },
      "retry a garment image" => ->(s) { [ :post, s.retry_image_garment_path(s.garment) ] },
      "view a photo batch" => ->(s) { [ :get, s.wardrobe_photo_intake_path(s.photo_batch) ] },
      "commit a photo batch" => ->(s) { [ :post, s.commit_wardrobe_intake_batch_path(s.photo_batch) ] },
      "discard a photo batch" => ->(s) { [ :delete, s.wardrobe_intake_batch_path(s.photo_batch) ] },
      "edit a draft" => ->(s) { [ :patch, s.wardrobe_draft_path(s.photo_batch.garment_drafts.first) ] },
      "view a receipt" => ->(s) { [ :get, s.wardrobe_receipt_path(s.receipt_batch) ] },
      "commit a receipt" => ->(s) { [ :post, s.commit_wardrobe_intake_batch_path(s.receipt_batch) ] },
      "discard a receipt" => ->(s) { [ :delete, s.wardrobe_intake_batch_path(s.receipt_batch) ] }
    }.each do |action, route|
      it "returns 404 when another user tries to #{action}, and changes nothing" do
        method, path = route.call(self)
        counts = -> { [ Garment.count, IntakeBatch.count, GarmentDraft.where(status: "committed").count ] }
        before_counts = counts.call
        send(method, path, params: { hidden: "true", draft: { name: "Hijacked" }, garment: { name: "Hijacked" } })
        expect(response).to have_http_status(:not_found)
        expect(counts.call).to eq(before_counts)
        expect(Garment.where(name: "Hijacked")).to be_empty
      end
    end

    it "never renders a link to an uploaded source photo, even for the owner" do
      sign_in owner
      batch = create(:intake_batch, user: owner, status: "processing")
      batch.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "me.jpg",
                               content_type: "image/jpeg")
      get wardrobe_photo_intake_path(batch)
      expect(response.body).not_to include(batch.source_file.blob.signed_id, "me.jpg")
    end
  end

  describe "sensitive data" do
    it "filters pasted receipt text from the request logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      expect(filter.filter("receipt_text" => "Jane Doe, 1 Main St, Visa 4242")).to eq("receipt_text" => "[FILTERED]")
    end
  end

  describe "AI quotas for photo and receipt analysis (design doc 3.5)" do
    it "stops photo analysis at the daily vision cap with a clear message" do
      batch = create(:intake_batch, user: owner, status: "processing")
      batch.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "o.jpg",
                               content_type: "image/jpeg")
      with_env("AI_DAILY_VISION_LIMIT" => "0") { Wardrobe::ExtractGarmentsJob.perform_now(batch.id) }
      expect(batch.reload.error).to eq(Wardrobe::ExtractGarmentsJob::QUOTA_REACHED)
      expect(batch.garment_drafts).to be_empty
    end

    it "stops receipt image reading at the daily vision cap with a clear message" do
      batch = create(:intake_batch, :receipt, user: owner, status: "processing")
      batch.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/receipt.jpg")), filename: "r.jpg",
                               content_type: "image/jpeg")
      with_env("AI_DAILY_VISION_LIMIT" => "0") { Receipts::ParseImageJob.perform_now(batch.id) }
      expect(batch.reload.error).to eq(Receipts::ParseImageJob::QUOTA_REACHED)
    end

    it "counts each user's vision calls separately" do
      create(:ai_call, user: intruder, kind: "garment_extraction", images_in: 1)
      client = Ai::Client.current
      with_env("AI_DAILY_VISION_LIMIT" => "1") do
        expect { client.generate_json(kind: :garment_extraction, prompt: "x", schema: {}, images: [ :img ], user: intruder) }
          .to raise_error(Ai::QuotaExceededError)
        expect { client.generate_json(kind: :garment_extraction, prompt: "x", schema: {}, images: [ :img ], user: owner) }
          .not_to raise_error
      end
    end

    it "stops every paid call once the global daily budget is spent" do
      create(:ai_call, est_cost_cents: 1_000)
      with_env("AI_DAILY_BUDGET_CENTS" => "1000") do
        expect { Ai::Client.current.generate_json(kind: :receipt_extraction, prompt: "x", schema: {}, user: owner) }
          .to raise_error(Ai::QuotaExceededError)
      end
    end
  end

  describe "transaction boundaries" do
    before { sign_in owner }

    it "leaves no photo batch behind when storing the upload fails" do
      allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_raise(ActiveRecord::RecordInvalid)
      post wardrobe_photo_intakes_path, params: { photo: photo }
      expect(response).to have_http_status(:unprocessable_entity) # rescued by Rails (show_exceptions: :rescuable)
      expect(IntakeBatch.count).to eq(0)
      expect(enqueued_jobs).to be_empty
    end

    it "leaves no receipt image batch behind when storing the upload fails" do
      allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_raise(ActiveRecord::RecordInvalid)
      receipt = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/receipt.jpg"), "image/jpeg")
      post wardrobe_receipts_path, params: { receipt_file: receipt }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(IntakeBatch.count).to eq(0)
    end

    it "queues the photo job only once the photo is committed and stored, so it cannot run before them" do
      stored_at_enqueue = nil
      allow(Wardrobe::ExtractGarmentsJob).to receive(:perform_later).and_wrap_original do |original, batch_id|
        batch = IntakeBatch.find(batch_id)
        stored_at_enqueue = batch.source_file.attached? && ActiveStorage::Blob.service.exist?(batch.source_file.blob.key)
        original.call(batch_id)
      end
      post wardrobe_photo_intakes_path, params: { photo: photo }
      expect(stored_at_enqueue).to be(true)
    end

    [ [ "photo", -> { post wardrobe_photo_intakes_path, params: { photo: photo } }, Wardrobe::ExtractGarmentsJob ],
      [ "receipt image", lambda {
        post wardrobe_receipts_path,
             params: { receipt_file: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/receipt.jpg"), "image/jpeg") }
      }, Receipts::ParseImageJob ] ].each do |label, request, job|
      it "leaves no batch, blob row or stored file when queueing the #{label} job fails" do
        stored_keys = []
        allow_any_instance_of(ActiveStorage::Blob).to receive(:upload_without_unfurling).and_wrap_original do |original, *args|
          stored_keys << original.receiver.key
          original.call(*args)
        end
        allow(job).to receive(:perform_later).and_raise(ActiveRecord::ConnectionNotEstablished)

        # The request still fails (the error is re-raised after cleanup), but nothing is left behind.
        expect { instance_exec(&request) }.to raise_error(ActiveRecord::ConnectionNotEstablished)
        expect(IntakeBatch.count).to eq(0)
        expect(ActiveStorage::Blob.count).to eq(0)
        expect(stored_keys).not_to be_empty
        expect(stored_keys.map { ActiveStorage::Blob.service.exist?(_1) }).to all(be(false))
      end
    end

    it "leaves no half-made receipt batch when a draft cannot be saved" do
      allow_any_instance_of(GarmentDraft).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      post wardrobe_receipts_path, params: { receipt_text: "Linen shirt $30.00" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(IntakeBatch.count).to eq(0)
    end

    it "commits photo drafts and the ready status together, so a crash in between leaves neither" do
      batch = create(:intake_batch, user: owner, status: "processing")
      batch.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "o.jpg",
                               content_type: "image/jpeg")
      allow_any_instance_of(IntakeBatch).to receive(:update!).and_wrap_original do |original, *args, **kwargs|
        raise "worker died" if kwargs[:status] == "ready" || args.first.try(:[], :status) == "ready"

        original.call(*args, **kwargs)
      end

      expect { Wardrobe::ExtractGarmentsJob.perform_now(batch.id) }.to raise_error(RuntimeError, "worker died")
      expect(batch.garment_drafts.count).to eq(0) # and the failure handler does not insert them again
      expect(batch.reload.status).to eq("failed")
    end

    it "does not add drafts twice when the extraction job runs again" do
      batch = create(:intake_batch, user: owner, status: "processing")
      batch.source_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/outfit.jpg")), filename: "o.jpg",
                               content_type: "image/jpeg")
      2.times { Wardrobe::ExtractGarmentsJob.perform_now(batch.id) } # e.g. Solid Queue re-running a crashed job
      expect(batch.reload.garment_drafts.count).to eq(2)
      expect(Ai::Client::Fake.calls.count { _1[:kind] == "garment_extraction" }).to eq(1)
    end

    it "limits each intake job to one run per batch" do
      expect(Wardrobe::ExtractGarmentsJob.concurrency_limit).to eq(1)
      expect(Receipts::ParseImageJob.concurrency_limit).to eq(1)
      expect(Wardrobe::ExtractGarmentsJob.new("b1").concurrency_key).to include("intake-batch-b1")
      expect(Receipts::ParseImageJob.new("b1").concurrency_key).to include("intake-batch-b1")
    end

    it "copes with draft ids that are not UUIDs in review edits" do
      batch = create(:intake_batch, user: owner, status: "ready")
      create(:garment_draft, :ready, intake_batch: batch)
      post commit_wardrobe_intake_batch_path(batch), params: { drafts: { "not-a-uuid" => { name: "x" }, "1 OR 1=1" => { name: "y" } } }
      expect(response).to redirect_to(wardrobe_path)
      expect(owner.garments.count).to eq(1)
    end
  end

  describe "CSRF with forms rendered by broadcasts" do
    around do |example|
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "accepts a form whose embedded token came from the broadcast renderer, via Turbo's X-CSRF-Token header" do
      sign_in owner
      garment = create(:garment, user: owner)
      get wardrobe_path
      header_token = Nokogiri::HTML5(response.body).at('meta[name="csrf-token"]')["content"]

      patch hide_garment_path(garment), params: { hidden: "true", authenticity_token: "from-the-broadcast-renderer" },
                                        headers: { "X-CSRF-Token" => header_token }
      expect(response).to have_http_status(:redirect)
      expect(garment.reload.hidden_from_recommendations).to be(true)
    end

    it "still rejects a request with neither a valid form token nor the header" do
      sign_in owner
      garment = create(:garment, user: owner)
      get wardrobe_path
      patch hide_garment_path(garment), params: { hidden: "true", authenticity_token: "forged" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(garment.reload.hidden_from_recommendations).to be(false)
    end
  end
end
