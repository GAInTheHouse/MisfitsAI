# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::RecommendationEngine, type: :service do
  let(:user) { create(:user) }

  it "returns nil when user has no garments" do
    engine = described_class.new(user: user)
    expect(engine.call).to be_nil
  end

  it "recommends garments when user has garments" do
    create(:garment, user: user, category: "top", hidden_from_recommendations: false)
    engine = described_class.new(user: user)
    expect(engine.call).not_to be_empty
  end
end
