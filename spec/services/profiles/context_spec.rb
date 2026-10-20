# frozen_string_literal: true

require "rails_helper"

RSpec.describe Profiles do
  describe ".for" do
    it "returns profile and measurement fields" do
      user = create(:user, :onboarded, :with_profile, :with_measurements)
      ctx = described_class.for(user)

      expect(ctx.gender).to eq("female")
      expect(ctx.color_tone).to eq("warm")
      expect(ctx.measurements[:height_cm]).to eq(170.0)
      expect(ctx.avatar_attached?).to be(false)
    end
  end
end
