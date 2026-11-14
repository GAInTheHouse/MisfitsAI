# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation do
  describe ".build" do
    subject(:progress) { described_class.build(user) }

    let(:user) { create(:user, time_zone: "America/New_York") }

    describe "wardrobe_complete" do
      it "is false with no garments" do
        expect(progress.wardrobe_complete).to be false
      end

      it "is false with only a top" do
        create(:garment, user: user, category: "top")
        expect(progress.wardrobe_complete).to be false
      end

      it "is true with a top and a bottom" do
        create(:garment, user: user, category: "top")
        create(:garment, user: user, category: "bottom")
        expect(Navigation.build(user).wardrobe_complete).to be true
      end

      it "is true with just a dress" do
        create(:garment, user: user, category: "dress")
        expect(Navigation.build(user).wardrobe_complete).to be true
      end

      it "is false when top+bottom are hidden" do
        create(:garment, user: user, category: "top", hidden_from_recommendations: true)
        create(:garment, user: user, category: "bottom", hidden_from_recommendations: true)
        expect(Navigation.build(user).wardrobe_complete).to be false
      end
    end

    describe "calendar_complete" do
      let(:this_week_start) { Planner::Week.current_start(user) }

      it "is false with no week plan" do
        expect(progress.calendar_complete).to be false
      end

      it "is false when all events are none" do
        plan = create(:week_plan, user: user, week_start: this_week_start)
        create(:week_event, week_plan: plan, event_type: "none")
        expect(Navigation.build(user).calendar_complete).to be false
      end

      it "is true when at least one event is non-none for the current week" do
        plan = create(:week_plan, user: user, week_start: this_week_start)
        create(:week_event, week_plan: plan, event_type: "work_meeting")
        expect(Navigation.build(user).calendar_complete).to be true
      end

      it "is true when the plan source is demo" do
        create(:week_plan, user: user, week_start: this_week_start, source: "demo")
        expect(Navigation.build(user).calendar_complete).to be true
      end

      it "is true when the plan source is google" do
        create(:week_plan, user: user, week_start: this_week_start, source: "google")
        expect(Navigation.build(user).calendar_complete).to be true
      end

      it "is true when Google Calendar is connected regardless of events" do
        create(:week_plan, user: user, week_start: this_week_start)
        user.update!(google_calendar_connected_at: 1.hour.ago)
        expect(Navigation.build(user).calendar_complete).to be true
      end

      it "is false when only a past week has non-none events" do
        past_start = this_week_start - 7
        plan = create(:week_plan, user: user, week_start: past_start)
        create(:week_event, week_plan: plan, event_type: "work_meeting")
        expect(Navigation.build(user).calendar_complete).to be false
      end

      it "respects the user's time zone when determining the current week" do
        # Place the user in UTC+14 (Kiritimati) so their Monday may differ from UTC's Monday.
        user.update!(time_zone: "Pacific/Kiritimati")
        expected_start = Planner::Week.current_start(user)
        plan = create(:week_plan, user: user, week_start: expected_start)
        create(:week_event, week_plan: plan, event_type: "casual")
        expect(Navigation.build(user).calendar_complete).to be true
      end
    end

    describe "outfits_complete" do
      let(:this_week_start) { Planner::Week.current_start(user) }

      it "is false with no recommendations" do
        expect(progress.outfits_complete).to be false
      end

      it "is true when outfit recommendations exist for the current week" do
        plan = create(:week_plan, user: user, week_start: this_week_start)
        create(:outfit_recommendation, week_plan: plan)
        expect(Navigation.build(user).outfits_complete).to be true
      end

      it "is false when only a past week has recommendations" do
        past_plan = create(:week_plan, user: user, week_start: this_week_start - 7)
        create(:outfit_recommendation, week_plan: past_plan)
        expect(Navigation.build(user).outfits_complete).to be false
      end
    end
  end
end
