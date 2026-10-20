# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Kinds do
  it "lists every AI kind from the routing table" do
    expect(described_class::ALL.size).to eq(10)
    expect(described_class::IMAGE_OUTPUT).to include("garment_image")
    expect(described_class::IMAGE_INPUT).to include("garment_extraction")
  end
end
