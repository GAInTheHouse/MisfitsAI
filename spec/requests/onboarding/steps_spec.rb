# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding steps", type: :request do
  let(:user) { create(:user, :new_user) }

  before { sign_in user }

  it "re-renders step 0 when the birthday is invalid" do
    patch onboarding_path, params: { user_profile: { gender: "female", birthday: "not-a-date" } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Use YYYY-MM-DD format")
    expect(user.reload.onboarding_step).to eq(0)
  end

  it "shows a validation message on step 3 when no items are selected" do
    user.update!(onboarding_step: 3)

    patch onboarding_path, params: { reviewed_items: {}, custom_items: {} }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Add at least one item to continue.")
    expect(user.reload.onboarding_step).to eq(3)
  end

  it "moves back one step" do
    user.update!(onboarding_step: 2)

    post back_onboarding_path

    expect(response).to redirect_to(onboarding_path)
    expect(user.reload.onboarding_step).to eq(1)
  end

  it "completes onboarding on step 5" do
    user.update!(onboarding_step: 5)

    patch onboarding_path

    expect(response).to redirect_to(wardrobe_path)
    expect(flash[:notice]).to eq("Welcome to your wardrobe!")
    expect(user.reload.onboarding_completed_at).to be_present
    expect(user.onboarding_step).to eq(5)
  end
  # Regression & feature coverage for issue #50
  it "pluralizes category headings properly on step 2 without SHOESS or OUTERWEARS" do
    user.update!(onboarding_step: 2)

    get onboarding_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to match(/>\s*(SHOESS|OUTERWEARS)\s*</i)
    expect(response.body).to include("Shoes")
    expect(response.body).to include("Outerwear")
    expect(response.body).to include("Add your own items")
  end

  it "allows adding a manual garment during onboarding and continuing past step 3 without starter catalog items" do
    user.update!(onboarding_step: 2)

    post garments_path, params: {
      garment: { name: "Navy Linen Blazer", category: "outerwear", color_primary: "navy" },
      generate_image: "0"
    }
    expect(response).to redirect_to(onboarding_path)
    expect(user.garments.reload.pluck(:name)).to include("Navy Linen Blazer")

    # Advance from step 2 with no starter catalog selections
    patch onboarding_path, params: {}
    expect(response).to redirect_to(onboarding_path)
    expect(user.reload.onboarding_step).to eq(3)

    # Step 3 shows the already-added garment and allows building the wardrobe
    get onboarding_path
    expect(response.body).to include("Navy Linen Blazer")

    patch onboarding_path, params: { reviewed_items: {}, custom_items: {} }
    expect(response).to redirect_to(onboarding_path)
    expect(user.reload.onboarding_step).to eq(4)
  end
end
