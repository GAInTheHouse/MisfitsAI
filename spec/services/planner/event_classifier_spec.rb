# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::EventClassifier do
  it "classifies gym keywords first" do
    expect(described_class.call("Yoga class")).to eq("gym")
    expect(described_class.call("Morning run")).to eq("gym")
  end

  it "classifies work meetings" do
    expect(described_class.call("Sprint planning")).to eq("work_meeting")
    expect(described_class.call("Client presentation")).to eq("work_meeting")
  end

  it "classifies date night" do
    expect(described_class.call("Anniversary dinner")).to eq("date_night")
  end

  it "defaults Call Mom to casual" do
    expect(described_class.call("Call Mom")).to eq("casual")
  end

  it "uses first matching rule when gym and work keywords overlap" do
    expect(described_class.call("workout meeting")).to eq("gym")
  end
end
