# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  it "connects a signed-in user, identified as current_user" do
    connect "/cable", env: { "warden" => instance_double(Warden::Proxy, user: user) }
    expect(connection.current_user).to eq(user)
  end

  it "refuses a connection without a signed-in user" do
    expect { connect "/cable", env: { "warden" => instance_double(Warden::Proxy, user: nil) } }.to have_rejected_connection
    expect { connect "/cable" }.to have_rejected_connection
  end
end

RSpec.describe Turbo::StreamsChannel, type: :channel do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }

  def signed(*streamables) = described_class.signed_stream_name(streamables)

  it "lets a user subscribe to their own wardrobe stream" do
    stub_connection current_user: owner
    subscribe signed_stream_name: signed(owner, :wardrobe)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(described_class.send(:stream_name_from, [ owner, :wardrobe ]))
  end

  it "rejects another user's stream even with a valid signature" do
    stub_connection current_user: other
    subscribe signed_stream_name: signed(owner, :wardrobe)
    expect(subscription).to be_rejected
  end

  it "rejects streams that do not start with a user, and tampered names" do
    stub_connection current_user: owner
    subscribe signed_stream_name: signed(:wardrobe)
    expect(subscription).to be_rejected
    subscribe signed_stream_name: signed(create(:garment, user: owner))
    expect(subscription).to be_rejected
    subscribe signed_stream_name: "#{signed(owner, :wardrobe)}tampered"
    expect(subscription).to be_rejected
  end

  it "rejects a subscription without a current user" do
    stub_connection current_user: nil
    subscribe signed_stream_name: signed(owner, :wardrobe)
    expect(subscription).to be_rejected
  end
end
