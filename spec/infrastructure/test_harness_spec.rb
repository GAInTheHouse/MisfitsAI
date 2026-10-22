# frozen_string_literal: true

require "rails_helper"

# Checks the shared test infrastructure added in Phase 2 Step 2.
RSpec.describe "Test harness" do
  describe "factories" do
    # Scoped to Phase 2 factories: Phase 1's :user_profile factory is a known issue (it duplicates the
    # profile User creates in after_create). See docs/handoff/phase-2.md.
    it "builds a valid record for every Phase 2 factory and trait" do
      phase_2 = FactoryBot.factories.select { %i[garment intake_batch garment_draft].include?(_1.name) }
      expect(phase_2.size).to eq(3)
      expect { FactoryBot.lint(phase_2, traits: true) }.not_to raise_error
    end

    it "attaches a JPEG for :with_image garments" do
      garment = create(:garment, :with_image)
      expect(garment.image).to be_attached
      expect(garment.image.content_type).to eq("image/jpeg")
      expect(garment.image_status).to eq("ready")
    end
  end

  describe "Action Cable" do
    it "uses the test adapter so broadcasts can be asserted" do
      expect(ActionCable.server.pubsub).to be_a(ActionCable::SubscriptionAdapter::Test)
      expect { ActionCable.server.broadcast("harness", { ok: true }) }.to have_broadcasted_to("harness")
    end
  end

  describe "Phase 2 option lists (design doc 12.3)" do
    it "has the full starter catalog with valid categories and formality" do
      catalog = Options.fetch(:starter_catalog)
      expect(catalog.size).to eq(21)
      expect(catalog.map { _1[:id] }.uniq.size).to eq(21)
      expect(catalog.map { _1[:category] }).to all(be_in(Garment::CATEGORIES))
      expect(catalog.map { _1[:formality] }).to all(be_in(Garment::FORMALITIES))
    end

    it "has the search lists" do
      expect(Options.fetch(:search_brands).size).to eq(51)
      expect(Options.fetch(:search_materials).size).to eq(21)
      expect(Options.fetch(:search_colors).size).to eq(30)
    end

    it "has search kinds for every garment category" do
      kinds = Options.fetch(:search_kinds_by_category)
      expect(kinds.keys.map(&:to_s)).to match_array(Garment::CATEGORIES)
      expect(kinds.values).to all(be_present)
    end
  end
end
