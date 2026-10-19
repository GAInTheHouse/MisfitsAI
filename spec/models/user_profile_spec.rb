# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserProfile do
  it "rejects overlapping favorite and avoided colors" do
    profile = build(:user_profile, favorite_colors: %w[blue], avoided_colors: %w[blue])
    expect(profile).not_to be_valid
    expect(profile.errors[:base]).to include("A color can't be both favorite and avoided")
  end
end
