# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::GoogleToken do
  it "fetches and caches an access token" do
    creds = instance_double(Google::Auth::ServiceAccountCredentials)
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(creds)
    allow(creds).to receive(:fetch_access_token!).and_return(
      { "access_token" => "abc", "expires_in" => 3600 }
    )
    ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = '{"client_email":"x"}'

    expect(described_class.fetch).to eq("abc")
    expect(described_class.fetch).to eq("abc")
    expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds).once
  end
end
