require "rails_helper"
RSpec.describe Planner::RecommendationEngine do
  let(:garments) { [] }
  let(:events) { [ double(date: Date.today, event_type: "casual", chain: nil) ] }
  let(:context) { double(avoided_colors: [], favorite_colors: [], color_tone: nil, measurements: nil, gender: nil) }
  before do
    allow_any_instance_of(Planner::RecommendationEngine).to receive(:pick_outerwear).and_return(double(id: 1, category: "outerwear"))
    allow_any_instance_of(Planner::RecommendationEngine).to receive(:pick).and_return(double(id: 2, category: "top"))
    allow_any_instance_of(Planner::RecommendationEngine).to receive(:pick_shoes).and_return(double(id: 3, category: "shoes"))
  end
  it "adds outerwear when the forecast is cold" do
    forecasts = { Date.today => { temp_f: 40, condition: "cloudy" } }
    outfits = described_class.call(garments: garments, events: events, context: context, forecasts: forecasts)
    expect(outfits.first.outerwear).not_to be_nil
  end
  it "omits outerwear when hot" do
    forecasts = { Date.today => { temp_f: 85, condition: "sunny" } }
    outfits = described_class.call(garments: garments, events: events, context: context, forecasts: forecasts)
    expect(outfits.first.outerwear).to be_nil
  end
end
