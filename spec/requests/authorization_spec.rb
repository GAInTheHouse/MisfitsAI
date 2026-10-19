# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authorization", type: :request do
  let(:user_a) { create(:user, :onboarded) }
  let(:user_b) { create(:user, :onboarded) }
  let!(:garment) { create(:garment, user: user_a) }

  before { sign_in user_b }

  it "returns 404 for another user's garment edit" do
    get edit_garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for hide" do
    patch hide_garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for destroy" do
    delete garment_path(garment)
    expect(response).to have_http_status(:not_found)
  end
end
