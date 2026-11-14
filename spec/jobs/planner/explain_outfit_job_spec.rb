# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::ExplainOutfitJob, type: :job do
  let(:user) { create(:user) }
  let(:plan) { create(:week_plan, user:) }
  let(:top) { create(:garment, :top, user:) }
  let!(:rec) do
    create(:outfit_recommendation, week_plan: plan, top:, event_type: "work_meeting", explanation_status: "pending")
  end

  it "writes AI explanation and marks ready" do
    described_class.perform_now(rec.id)
    rec.reload
    expect(rec.explanation).to be_present
    expect(rec.explanation_status).to eq("ready")
  end

  it "uses template when grounded and text fail" do
    Ai::Client::Fake.stub("outfit_explanation", Ai::TransientError.new("down"))

    described_class.perform_now(rec.id)
    rec.reload
    expect(rec.explanation).to include("best available pieces")
    expect(rec.explanation_status).to eq("failed")
  end

  it "text fallback receives plain strings, not raw Hash objects" do
    # Prompts.facts returns [{text:, title:}] hashes. The fallback must extract :text before
    # joining — not call facts.join("\n") which would put {:text=>...} garbage in the prompt.
    allow_any_instance_of(Ai::Client::Fake).to receive(:grounded_text).and_raise(Ai::TransientError.new("down"))

    described_class.perform_now(rec.id)

    text_call = Ai::Client::Fake.calls.find { _1[:method] == :generate_text }
    expect(text_call).not_to be_nil
    expect(text_call[:prompt]).not_to match(/\{:?["']?text["']?=>/)
    expect(rec.reload.explanation_status).to eq("ready")
  end
end
