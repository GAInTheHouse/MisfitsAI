# frozen_string_literal: true

require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change
RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

RSpec.describe Wardrobe::AddGarments do
  let(:user) { create(:user) }
  let(:items) do
    [
      { name: "Oxford Shirt", category: "top", color: "White", size: "M", brand: "Uniqlo", price_cents: 3990,
        fit_notes: "Receipt price: $39.90" },
      { "name" => "Slim Chinos", "category" => "bottom", "color_primary" => "khaki", "size" => "32" }
    ]
  end

  it "creates the garments for the user and returns them in order (design doc 4.2)" do
    garments = described_class.call(user: user, items: items, source: :receipt)

    expect(garments).to all(be_a(Garment).and(be_persisted))
    expect(garments.map(&:name)).to eq([ "Oxford Shirt", "Slim Chinos" ])
    expect(garments.map(&:user)).to all(eq(user))
    expect(garments.map(&:source)).to all(eq("receipt"))
  end

  it "maps item keys onto garment columns, accepting color as color_primary" do
    shirt, chinos = described_class.call(user: user, items: items, source: :receipt)

    expect(shirt).to have_attributes(color_primary: "white", size: "M", brand: "Uniqlo", price_cents: 3990,
                                     fit_notes: "Receipt price: $39.90")
    expect(chinos.color_primary).to eq("khaki")
  end

  it "ignores keys that are not garment fields" do
    other = create(:user)
    garment = described_class.call(
      user: user, source: :receipt,
      items: [ { name: "Tee", category: "top", user_id: other.id, times_recommended: 5, confidence: 0.4 } ]
    ).first

    expect(garment).to have_attributes(user_id: user.id, times_recommended: 0)
  end

  context "with generate_images: true (the default)" do
    it "saves the garments as pending and queues one image job each" do
      garments = nil
      expect { garments = described_class.call(user: user, items: items, source: :receipt) }
        .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).exactly(2).times

      expect(garments.map(&:image_status)).to all(eq("pending"))
      garments.each { |g| expect(Wardrobe::GenerateGarmentImageJob).to have_been_enqueued.with(g.id) }
    end
  end

  context "with generate_images: false" do
    it "saves the garments with the placeholder and queues nothing" do
      garments = nil
      expect { garments = described_class.call(user: user, items: items, source: :receipt, generate_images: false) }
        .not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
      expect(garments.map(&:image_status)).to all(eq("placeholder"))
    end
  end

  it "saves nothing and queues nothing when any item is invalid" do
    bad = items + [ { name: "", category: "top" } ]

    expect { described_class.call(user: user, items: bad, source: :receipt) }
      .to raise_error(ActiveRecord::RecordInvalid)
      .and not_change(Garment, :count)
      .and not_have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
  end

  describe "queueing only after commit (the caller may hold an outer transaction, e.g. onboarding)" do
    include ActiveJob::TestHelper

    it "queues nothing when the caller's transaction rolls back" do
      expect do
        ActiveRecord::Base.transaction do
          described_class.call(user: user, items: items, source: :starter)
          raise ActiveRecord::Rollback
        end
      end.to not_change(Garment, :count).and not_have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
    end

    it "waits for the caller's transaction to commit before queueing" do
      queued_inside = nil
      ActiveRecord::Base.transaction do
        described_class.call(user: user, items: items, source: :starter)
        queued_inside = enqueued_jobs.count { _1["job_class"] == "Wardrobe::GenerateGarmentImageJob" }
      end

      expect(queued_inside).to eq(0)
      expect(enqueued_jobs.count { _1["job_class"] == "Wardrobe::GenerateGarmentImageJob" }).to eq(2)
    end
  end

  it "rejects an unknown source" do
    expect { described_class.call(user: user, items: items, source: :magic) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "returns an empty list for no items" do
    expect(described_class.call(user: user, items: [], source: :receipt)).to eq([])
  end
end
