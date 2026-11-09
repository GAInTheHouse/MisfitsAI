# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::WeekPlanner, type: :service do
  let(:user) { create(:user) }

  describe ".apply_demo_week!" do
    it "uses the design doc demo map" do
      plan = described_class.ensure_week!(user:)
      described_class.apply_demo_week!(plan)
      types = plan.week_events.order(:date).pluck(:event_type)
      expect(types).to eq(%w[work_meeting work_meeting gym work_meeting date_night casual none])
    end
  end

  describe ".generate!" do
    it "creates recommendations and increments counters" do
      top = create(:garment, :top, user:, formality: "business")
      bottom = create(:garment, :bottom, user:, formality: "business")
      plan = described_class.ensure_week!(user:)
      described_class.apply_demo_week!(plan)

      expect {
        described_class.generate!(user:, week_plan: plan)
      }.to have_enqueued_job(Planner::ExplainOutfitJob).exactly(7).times

      expect(plan.outfit_recommendations.count).to eq(7)
      expect(top.reload.times_recommended).to be >= 1
      expect(bottom.reload.times_recommended).to be >= 1
      expect(plan.reload.generated_at).to be_present
    end
  end
end
