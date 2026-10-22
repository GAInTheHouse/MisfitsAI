# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receipts", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :onboarded) }
  let(:receipt_text) { "UNIQLO\nOrder #12345\nOxford Shirt White M $39.90\nSlim Fit Chinos Khaki 32 $49.90\nTotal $89.80" }

  def upload(path, type) = Rack::Test::UploadedFile.new(Rails.root.join(path), type)

  # UUID primary keys: .last without an order is not "newest", so order by creation time.
  def latest_receipt = user.intake_batches.receipts.order(:created_at).last

  def temp_upload(bytes, name: "receipt.bin", type: "application/octet-stream")
    file = Tempfile.new([ "upload", File.extname(name) ]).tap { |f| f.binmode; f.write(bytes); f.rewind }
    Rack::Test::UploadedFile.new(file.path, type, original_filename: name)
  end

  before { sign_in user }

  describe "POST /wardrobe/receipts" do
    it "parses pasted text in the request into ready drafts (text_rules)" do
      post wardrobe_receipts_path, params: { receipt_text: receipt_text }

      batch = latest_receipt
      expect(response).to redirect_to(wardrobe_receipt_path(batch))
      expect(batch).to have_attributes(status: "ready", parser_strategy: "text_rules")
      expect(batch.extracted_text_preview).to start_with("UNIQLO")
      expect(batch.source_file).not_to be_attached
      expect(batch.garment_drafts.ordered.map { _1.attrs.slice("name", "price_cents", "brand") }).to eq([
        { "name" => "Oxford Shirt White", "price_cents" => 3990, "brand" => "Uniqlo" },
        { "name" => "Slim Fit Chinos Khaki", "price_cents" => 4990, "brand" => "Uniqlo" }
      ])
    end

    it "parses a PDF in the request (pdf_text_rules) without storing it" do
      post wardrobe_receipts_path, params: { receipt_file: upload("spec/fixtures/files/receipt.pdf", "application/pdf") }
      batch = latest_receipt
      expect(batch).to have_attributes(status: "ready", parser_strategy: "pdf_text_rules")
      expect(batch.garment_drafts.count).to eq(2)
      expect(batch.source_file).not_to be_attached
    end

    it "parses a text file (plain_text_rules)" do
      post wardrobe_receipts_path, params: { receipt_file: temp_upload(receipt_text, name: "order.txt", type: "text/plain") }
      expect(latest_receipt).to have_attributes(status: "ready", parser_strategy: "plain_text_rules")
    end

    it "sends an image to the vision job (image_vision)" do
      expect { post wardrobe_receipts_path, params: { receipt_file: upload("spec/fixtures/files/receipt.jpg", "image/jpeg") } }
        .to have_enqueued_job(Receipts::ParseImageJob)
      batch = latest_receipt
      expect(batch).to have_attributes(status: "processing", parser_strategy: "image_vision")
      expect(batch.source_file).to be_attached
    end

    it "decides by content: a PDF named .jpg is read as a PDF" do
      pdf = File.binread(Rails.root.join("spec/fixtures/files/receipt.pdf"))
      post wardrobe_receipts_path, params: { receipt_file: temp_upload(pdf, name: "photo.jpg", type: "image/jpeg") }
      expect(latest_receipt.parser_strategy).to eq("pdf_text_rules")
    end

    it "marks the batch failed when no clothing items are found" do
      post wardrobe_receipts_path, params: { receipt_text: "Thank you for shopping with us!\nSee you soon." }
      expect(latest_receipt).to have_attributes(
        status: "failed", error: "We couldn't find any clothing items on that receipt."
      )
    end

    it "keeps priced lines that name no garment as flagged rows that start unselected ([DEVIATION])" do
      post wardrobe_receipts_path, params: { receipt_text: "Coffee 3.50\nLinen shirt $30.00" }
      coffee, shirt = latest_receipt.garment_drafts.ordered
      expect(coffee.attrs).to include("name" => "Coffee", "needs_confirmation" => true)
      expect([ coffee.selected, shirt.selected ]).to eq([ false, true ])

      post commit_wardrobe_intake_batch_path(latest_receipt)
      expect(user.garments.pluck(:name)).to eq([ "Linen Shirt" ])
    end

    {
      "a file over 10 MB" => -> { { receipt_file: temp_upload("%PDF-1.4\n" + ("0" * 11.megabytes), name: "big.pdf") } },
      "an empty file" => -> { { receipt_file: temp_upload("", name: "empty.pdf") } },
      "a binary file that is not a receipt" => -> { { receipt_file: temp_upload("\x00\x01\x02\x03".b * 100, name: "x.bin") } },
      "a damaged PDF" => -> { { receipt_file: temp_upload("%PDF-1.4\n%%EOF", name: "bad.pdf") } },
      "nothing" => -> { {} },
      "too much pasted text" => -> { { receipt_text: "x" * 20_001 } }
    }.each do |label, params|
      it "rejects #{label} with a message and creates nothing" do
        post wardrobe_receipts_path, params: instance_exec(&params)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match(/File too large|Uploaded file is empty|Please upload a receipt image, PDF or text file|We couldn&#39;t read that PDF|Paste receipt text or choose a file|That text is too long/)
        expect(IntakeBatch.count).to eq(0)
      end
    end

    it "is not available when the receipts feature is off" do
      allow(Feature).to receive(:enabled?).and_call_original
      allow(Feature).to receive(:enabled?).with(:receipts).and_return(false)
      post wardrobe_receipts_path, params: { receipt_text: receipt_text }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /wardrobe/receipts/:id" do
    it "shows editable rows, the flags and the extracted text, escaped" do
      post wardrobe_receipts_path, params: { receipt_text: "Graphic tee <script>alert(1)</script>\n" }
      get wardrobe_receipt_path(latest_receipt)

      doc = Nokogiri::HTML5(response.body)
      expect(doc.css("article.receipt-row").size).to eq(1)
      expect(response.body).to include("Please double-check", "Extracted text", "Generate product images", "Add selected")
      expect(doc.css("script").map(&:text).join).not_to include("alert(1)")
    end

    it "returns 404 for another user's receipt" do
      other = create(:intake_batch, :receipt, user: create(:user), status: "ready")
      get wardrobe_receipt_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "commit (POST /wardrobe/intake_batches/:id/commit)" do
    let(:batch) do
      post wardrobe_receipts_path, params: { receipt_text: receipt_text }
      latest_receipt
    end
    let(:shirt) { batch.garment_drafts.ordered.first }
    let(:chinos) { batch.garment_drafts.ordered.second }

    it "adds the selected rows as receipt garments with edits, price and the price note (design doc 6.12)" do
      post commit_wardrobe_intake_batch_path(batch), params: { generate_images: "1", drafts: {
        shirt.id => { selected: "1", name: "Oxford Shirt", brand: "Uniqlo", size: "M", color_primary: "White",
                      category: "top", price: "$42.50" },
        chinos.id => { selected: "0" }
      } }

      expect(response).to redirect_to(wardrobe_path)
      expect(flash[:notice]).to eq("1 item added")
      expect(user.garments.sole).to have_attributes(
        name: "Oxford Shirt", source: "receipt", price_cents: 4250, color_primary: "white", brand: "Uniqlo",
        size: "M", fit_notes: "Receipt price: $42.50", image_status: "pending"
      )
    end

    it "queues product images by default and skips them when unchecked" do
      expect { post commit_wardrobe_intake_batch_path(batch), params: { generate_images: "1" } }
        .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).exactly(2).times

      other = (post wardrobe_receipts_path, params: { receipt_text: receipt_text }) && latest_receipt
      expect { post commit_wardrobe_intake_batch_path(other), params: { generate_images: "0" } }
        .not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
      expect(user.garments.where(image_status: "placeholder").count).to eq(2)
    end

    it "keeps rows without a price, with no price note" do
      post commit_wardrobe_intake_batch_path(batch), params: { drafts: { shirt.id => { price: "" } } }
      expect(user.garments.find_by(name: "Oxford Shirt White")).to have_attributes(price_cents: nil, fit_notes: nil)
    end

    it "rejects a price that is not a number, saving nothing" do
      post commit_wardrobe_intake_batch_path(batch), params: { drafts: { shirt.id => { price: "about forty" } } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Price must be a number like 39.90")
      expect(user.garments).to be_empty
    end

    it "never adds the same receipt twice" do
      2.times { post commit_wardrobe_intake_batch_path(batch) }
      expect(user.garments.count).to eq(2)
      expect(flash[:notice]).to eq("No new items to add.")
    end

    it "returns 404 for another user's receipt" do
      other = create(:intake_batch, :receipt, user: create(:user), status: "ready")
      create(:garment_draft, :ready, intake_batch: other)
      post commit_wardrobe_intake_batch_path(other)
      expect(response).to have_http_status(:not_found)
      expect(Garment.count).to eq(0)
    end
  end

  it "discards a receipt and returns to the receipt form" do
    post wardrobe_receipts_path, params: { receipt_text: receipt_text }
    batch = latest_receipt
    delete wardrobe_intake_batch_path(batch)
    expect(response).to redirect_to(new_wardrobe_receipt_path)
    expect(IntakeBatch.exists?(batch.id)).to be(false)
  end
end
