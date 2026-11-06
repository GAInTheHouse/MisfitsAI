# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation do
  describe ".build" do
    subject(:progress) { described_class.build(user) }

    let(:user) { create(:user) }

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
      it "is false with no week plan" do
        expect(progress.calendar_complete).to be false
      end

      it "is false when all events are none" do
        plan = create(:week_plan, user: user, week_start: Date.current.beginning_of_week(:monday))
        create(:week_event, week_plan: plan, event_type: "none")
        expect(Navigation.build(user).calendar_complete).to be false
      end

      it "is true when at least one event is non-none for the current week" do
        plan = create(:week_plan, user: user, week_start: Date.current.beginning_of_week(:monday))
        create(:week_event, week_plan: plan, event_type: "work_meeting")
        expect(Navigation.build(user).calendar_complete).to be true
      end
    end

    describe "outfits_complete" do
      it "is false with no recommendations" do
        expect(progress.outfits_complete).to be false
      end

      it "is true when outfit recommendations exist" do
        plan = create(:week_plan, user: user)
        create(:outfit_recommendation, week_plan: plan)
        expect(Navigation.build(user).outfits_complete).to be true
      end
    end
  end
end
