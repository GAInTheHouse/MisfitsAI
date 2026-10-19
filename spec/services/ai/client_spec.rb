# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client do
  describe "quota guards" do
    let(:user) { create(:user) }
    let(:client) { Ai::Client::Fake.new }

    it "raises DisabledError when image generation is off" do
      ENV["AI_IMAGE_GEN_ENABLED"] = "false"
      expect {
        client.generate_image(kind: :garment_image, prompt: "x", user: user)
      }.to raise_error(Ai::DisabledError)
    ensure
      ENV.delete("AI_IMAGE_GEN_ENABLED")
    end

    it "raises QuotaExceededError when daily image cap is hit" do
      create_list(:ai_call, 40, user: user, images_out: 1, created_at: Time.current)
      expect {
        client.generate_image(kind: :garment_image, prompt: "x", user: user)
      }.to raise_error(Ai::QuotaExceededError)
    end
  end
end
