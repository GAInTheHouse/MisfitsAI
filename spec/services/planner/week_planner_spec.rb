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

  describe ".generate! with a multi-event day (issue #8)" do
    include ActiveSupport::Testing::TimeHelpers

    let(:zone) { ActiveSupport::TimeZone[user.time_zone] }
    let(:plan) { described_class.ensure_week!(user:) }
    let(:monday) { plan.week_events.order(:date).first }
    let!(:tee) { create(:garment, :top, user:, formality: "casual", name: "Gym Tee") }
    let!(:shirt) { create(:garment, :top, user:, formality: "business", name: "Oxford Shirt") }
    let!(:leggings) { create(:garment, :bottom, user:, formality: "casual", name: "Leggings") }
    let!(:trousers) { create(:garment, :bottom, user:, formality: "business", name: "Wool Trousers") }

    before do
      travel_to zone.parse("#{Date.current.beginning_of_week(:monday)} 08:00")
      monday.update!(event_type: "work_meeting")
      create(:calendar_event, week_event: monday, summary: "Spin class", event_type: "gym", position: 0,
                              starts_at: zone.parse("#{monday.date} 07:00"), ends_at: zone.parse("#{monday.date} 08:00"))
      create(:calendar_event, week_event: monday, summary: "Client pitch", event_type: "work_meeting", position: 1,
                              starts_at: zone.parse("#{monday.date} 10:00"), ends_at: zone.parse("#{monday.date} 11:00"))
    end

    it "writes one outfit per time block and one per other day" do
      recs = described_class.generate!(user:, week_plan: plan)
      expect(recs.size).to eq(8)

      gym, work = plan.outfit_recommendations.where(date: monday.date).in_day_order.to_a
      expect(gym).to have_attributes(segment_index: 0, event_type: "gym", top: tee, bottom: leggings,
                                     segment_label: "Morning: Spin class", change_reason: nil)
      expect(work).to have_attributes(segment_index: 1, event_type: "work_meeting", top: shirt, bottom: trousers)
      expect(work.change_reason).to start_with("Change after your workout")
      expect(work.starts_at).to eq(zone.parse("#{monday.date} 10:00"))
    end

    it "keeps a day whose outfit was worn and regenerates the rest" do
      described_class.generate!(user:, week_plan: plan)
      worn = plan.outfit_recommendations.find_by!(date: monday.date, segment_index: 0)
      worn.update!(worn_at: Time.current)

      described_class.generate!(user:, week_plan: plan)

      expect(plan.outfit_recommendations.where(date: monday.date).pluck(:id)).to include(worn.id)
      expect(plan.outfit_recommendations.where(date: monday.date).count).to eq(2)
      expect(plan.outfit_recommendations.count).to eq(8)
    end

    it "moves recently worn pieces behind unworn ones" do
      other_tee = create(:garment, :top, user:, formality: "casual", name: "Other Tee", times_recommended: 5)
      described_class.generate!(user:, week_plan: plan)
      plan.outfit_recommendations.find_by!(date: monday.date, segment_index: 0).update!(worn_at: Time.current)

      expect(described_class.recently_worn_ids(user)).to include(tee.id, leggings.id)
      tuesday = plan.outfit_recommendations.find_by!(date: monday.date + 1)
      described_class.generate!(user:, week_plan: plan)
      expect(plan.outfit_recommendations.find_by!(date: tuesday.date).top).to eq(other_tee)
    end
  end
end
