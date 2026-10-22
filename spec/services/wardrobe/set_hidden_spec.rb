# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wardrobe::SetHidden do
  let(:user) { create(:user) }
  let(:garment) { create(:garment, user: user, name: "Grey Hoodie") }

  it "hides a garment and returns it" do
    result = described_class.call(user: user, garment: garment, hidden: true)
    expect(result).to eq(garment)
    expect(garment.reload.hidden_from_recommendations).to be(true)
  end

  it "shows a hidden garment again" do
    garment.update!(hidden_from_recommendations: true)
    described_class.call(user: user, garment: garment, hidden: false)
    expect(garment.reload.hidden_from_recommendations).to be(false)
  end

  it "accepts form values such as \"true\" and \"false\"" do
    described_class.call(user: user, garment: garment, hidden: "true")
    expect(garment.reload.hidden_from_recommendations).to be(true)
    described_class.call(user: user, garment: garment, hidden: "false")
    expect(garment.reload.hidden_from_recommendations).to be(false)
  end

  it "broadcasts the refreshed card to the user's wardrobe stream (design doc 4.2)" do
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) do
      described_class.call(user: user, garment: garment, hidden: true)
    end

    card = streams.find { _1["target"] == "garment_#{garment.id}" }
    expect(card["action"]).to eq("replace")
    expect(card.text).to include("Hidden from outfits")
  end

  it "refreshes the wardrobe header, since planning counts visible garments only" do
    create(:garment, :top, user: user)
    bottom = create(:garment, :bottom, user: user)
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) do
      described_class.call(user: user, garment: bottom, hidden: true)
    end

    header = streams.find { _1["target"] == "wardrobe_status" }
    expect(header["action"]).to eq("replace")
    expect(header.text).to include("Add at least one top and one bottom to unlock outfit planning.")
  end

  it "broadcasts image paths, not URLs with a guessed host" do
    with_image = create(:garment, :with_image, user: user)
    streams = turbo_stream_broadcasts_to([ user, :wardrobe ]) do
      described_class.call(user: user, garment: with_image, hidden: true)
    end

    src = streams.first.at("template").children.to_html[/src="([^"]+)"/, 1]
    expect(src).to start_with("/rails/active_storage/representations/redirect/")
  end

  it "does not broadcast to other users' streams" do
    other = create(:user)
    streams = turbo_stream_broadcasts_to([ other, :wardrobe ]) do
      described_class.call(user: user, garment: garment, hidden: true)
    end
    expect(streams).to be_empty
  end

  it "refuses a garment that belongs to someone else" do
    foreign = create(:garment)
    expect { described_class.call(user: user, garment: foreign, hidden: true) }
      .to raise_error(ActiveRecord::RecordNotFound)
    expect(foreign.reload.hidden_from_recommendations).to be(false)
  end
end
