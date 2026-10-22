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

  it "records the kind's estimated cost by default and zero for a non-billable (failed) attempt" do
    described_class.log(kind: :garment_image, model: "m", status: "ok", latency_ms: 1)
    described_class.log(kind: :garment_image, model: "m", status: "error", latency_ms: 1, billable: false,
                        error_class: "Ai::TransientError")
    expect(AiCall.order(:created_at).pluck(:status, :est_cost_cents)).to eq([ [ "ok", 2.0 ], [ "error", 0 ] ])
  end
end
