# frozen_string_literal: true

require "rails_helper"

# Contract used by Phase 4 onboarding, step 3 "Build My Wardrobe" (design doc 4.2, 6.3).
RSpec.describe Wardrobe::StarterImport do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:catalog) { Options.fetch(:starter_catalog).index_by { _1[:id] } }
  let(:items) do
    [
      catalog.fetch("cat-white-tee").slice(:name, :category, :color, :formality, :sub_category).merge(size: "M"),
      { name: "Blue Jeans", category: "bottom", color: "blue", size: "32", formality: "casual", seasonality: "mild" }
    ]
  end

  it "creates starter garments right away with pending images and returns them" do
    garments = described_class.call(user: user, items: items)

    expect(garments.size).to eq(2)
    expect(garments).to all(be_persisted)
    expect(garments.map(&:source)).to all(eq("starter"))
    expect(garments.map(&:image_status)).to all(eq("pending"))
    expect(garments.first).to have_attributes(name: "White T-shirt", category: "top", color_primary: "white",
                                              size: "M", formality: "casual", sub_category: "t_shirt")
  end

  it "defaults the season to all_season but keeps a chosen one (design doc 12.3)" do
    tee, jeans = described_class.call(user: user, items: items)
    expect(tee.seasonality).to eq("all_season")
    expect(jeans.seasonality).to eq("mild")
  end

  it "queues one image job per garment and makes no AI call itself" do
    expect { described_class.call(user: user, items: items) }
      .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).exactly(2).times
    expect(Ai::Client::Fake.calls).to be_empty
  end

  it "ends with every garment's image ready once the jobs run" do
    garments = perform_enqueued_jobs { described_class.call(user: user, items: items) }
    expect(garments.map { _1.reload.image_status }).to all(eq("ready"))
  end

  it "accepts every starter catalog entry" do
    all_items = Options.fetch(:starter_catalog).map { _1.slice(:name, :category, :color, :formality, :sub_category) }
    expect(described_class.call(user: user, items: all_items).size).to eq(21)
  end
end
