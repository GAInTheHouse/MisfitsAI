# frozen_string_literal: true

require "rails_helper"

RSpec.describe Planner::EventClassifier do
  # Keyword lists copied from design doc 6.7 rather than from RULES, so a changed constant fails here.
  {
    "gym" => %w[gym workout fitness run running yoga crossfit pilates swim cycling hiit training],
    "work_meeting" => %w[meeting standup stand-up interview client presentation conference 1:1 sprint review
                         scrum retro all-hands],
    "date_night" => [ "date night", "romantic", "anniversary", "valentine" ]
  }.each do |type, keywords|
    keywords.each do |keyword|
      it "classifies #{keyword.inspect} as #{type}, in any case" do
        expect(described_class.call("Weekly #{keyword.upcase} thing")).to eq(type)
      end
    end
  end

  it "uses the first matching rule: gym, then work, then date night" do
    expect(described_class.call("workout meeting")).to eq("gym")
    expect(described_class.call("Anniversary client lunch")).to eq("work_meeting")
    expect(described_class.call("Romantic yoga retreat")).to eq("gym")
  end

  it "does not treat call or office as work keywords" do
    expect(described_class.call("Call Mom")).to eq("casual")
    expect(described_class.call("Office party")).to eq("casual")
  end

  it "keeps the documented substring quirk: Brunch matches run" do
    expect(described_class.call("Brunch with friends")).to eq("gym")
  end

  it "defaults blank and nil summaries to casual" do
    expect(described_class.call("")).to eq("casual")
    expect(described_class.call(nil)).to eq("casual")
  end

  it "orders same-day priority work_meeting > date_night > gym > casual" do
    priorities = %w[work_meeting date_night gym casual].map { described_class.priority(_1) }
    expect(priorities).to eq(priorities.sort.reverse)
    expect(priorities.uniq.size).to eq(4)
    expect(described_class.priority("none")).to eq(0)
  end
end
