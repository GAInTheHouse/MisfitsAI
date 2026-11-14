# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Laundry and Wear History", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  it "tracks wears, laundry state, wash-all, and wear history page" do
    top = Garment.create!(user:, name: "Linen Shirt", category: "top", source: "manual", price_cents: 5000)
    bottom = Garment.create!(user:, name: "Tan Trousers", category: "bottom", source: "manual")
    outfit = OutfitRecommendation.create!(week_plan: create(:week_plan, user:), date: Date.current, event_type: "casual", top:, bottom:)

    patch wear_outfit_path(outfit)
    expect(top.reload).to be_in_laundry
    expect(top.cost_per_wear_cents).to eq(5000)
    expect(bottom.reload).to be_clean

    patch wear_outfit_path(outfit)
    expect(top.reload).to be_clean

    patch laundry_garment_path(top)
    get wear_history_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Linen Shirt")

    post wash_all_wardrobe_path
    expect(top.reload).to be_clean
  end
end
