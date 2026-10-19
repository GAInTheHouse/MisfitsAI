# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::CallLogger do
  it "persists ai_calls rows" do
    user = create(:user)
    described_class.log(
      kind: :outfit_explanation,
      model: "fake",
      status: "ok",
      latency_ms: 5,
      user: user,
      input_chars: 10,
      output_chars: 20,
      images_in: 0,
      images_out: 0
    )
    expect(AiCall.last.user_id).to eq(user.id)
  end
end
