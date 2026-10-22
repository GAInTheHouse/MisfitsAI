# frozen_string_literal: true

require "rails_helper"

# Every credential here is a double or a throwaway local key; nothing reaches Google (WebMock blocks the network,
# and Google::Auth.get_application_default is always stubbed, because unstubbed it probes the GCE metadata server).
RSpec.describe Ai::GoogleToken do
  include ActiveSupport::Testing::TimeHelpers

  let(:scope) { described_class::SCOPE }
  let(:service_account) { instance_double(Google::Auth::ServiceAccountCredentials) }
  let(:adc) { instance_double(Google::Auth::UserRefreshCredentials) }

  around do |example|
    original = ENV.fetch("GOOGLE_SERVICE_ACCOUNT_JSON", nil)
    described_class.reset!
    example.run
  ensure
    original.nil? ? ENV.delete("GOOGLE_SERVICE_ACCOUNT_JSON") : ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = original
    described_class.reset!
  end

  def token(value, expires_in: 3600) = { "access_token" => value, "expires_in" => expires_in }

  describe "with GOOGLE_SERVICE_ACCOUNT_JSON (production path, unchanged)" do
    before do
      ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = '{"client_email":"x"}'
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(service_account)
      allow(service_account).to receive(:fetch_access_token!).and_return(token("sa-token"))
      allow(Google::Auth).to receive(:get_application_default)
    end

    it "uses the service-account key with the cloud-platform scope and never ADC" do
      expect(described_class.fetch).to eq("sa-token")
      expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds)
        .with(json_key_io: an_instance_of(StringIO), scope: scope)
      expect(Google::Auth).not_to have_received(:get_application_default)
    end

    it "reports its source as the service account" do
      expect(described_class.source).to eq("service account")
    end

    it "passes the JSON from the variable as the key" do
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds) do |json_key_io:, scope:|
        expect(json_key_io.read).to eq('{"client_email":"x"}')
        service_account
      end
      described_class.fetch
    end

    it "fetches and caches an access token" do
      expect(described_class.fetch).to eq("sa-token")
      expect(described_class.fetch).to eq("sa-token")
      expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds).once
    end

    it "works with a real (locally generated) key without contacting Google until a token is needed" do
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_call_original
      key = OpenSSL::PKey::RSA.new(2048)
      ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = {
        type: "service_account", project_id: "test-project", private_key_id: "1", private_key: key.to_pem,
        client_email: "test@test-project.iam.gserviceaccount.com", client_id: "1",
        token_uri: "https://oauth2.googleapis.com/token"
      }.to_json
      issuers = []
      allow_any_instance_of(Google::Auth::ServiceAccountCredentials).to receive(:fetch_access_token!) do |creds|
        issuers << creds.issuer
        token("real-key-token")
      end
      expect(described_class.fetch).to eq("real-key-token")
      expect(issuers).to eq([ "test@test-project.iam.gserviceaccount.com" ])
    end
  end

  describe "without a service-account key (Application Default Credentials)" do
    before do
      allow(Google::Auth).to receive(:get_application_default).and_return(adc)
      allow(adc).to receive(:fetch_access_token!).and_return(token("adc-token"))
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
    end

    it "uses ADC when the variable is absent" do
      ENV.delete("GOOGLE_SERVICE_ACCOUNT_JSON")
      expect(described_class.fetch).to eq("adc-token")
      expect(Google::Auth).to have_received(:get_application_default).with([ scope ])
      expect(Google::Auth::ServiceAccountCredentials).not_to have_received(:make_creds)
      expect(described_class.source).to eq("application default credentials")
    end

    [ "", "   ", "\n" ].each do |blank|
      it "uses ADC when the variable is blank (#{blank.inspect})" do
        ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = blank
        expect(described_class.fetch).to eq("adc-token")
        expect(Google::Auth::ServiceAccountCredentials).not_to have_received(:make_creds)
      end
    end
  end

  describe "token caching and expiry" do
    before do
      ENV.delete("GOOGLE_SERVICE_ACCOUNT_JSON")
      allow(Google::Auth).to receive(:get_application_default).and_return(adc)
    end

    it "reuses the token until 60 seconds before it expires, then fetches a new one" do
      allow(adc).to receive(:fetch_access_token!).and_return(token("first"), token("second"))
      freeze_time do
        expect(described_class.fetch).to eq("first")
        travel 3600.seconds - 61.seconds
        expect(described_class.fetch).to eq("first")
        travel 2.seconds # now inside the 60-second margin
        expect(described_class.fetch).to eq("second")
      end
      expect(adc).to have_received(:fetch_access_token!).twice
    end

    it "fetches a new token once the old one has expired" do
      allow(adc).to receive(:fetch_access_token!).and_return(token("first"), token("second"))
      freeze_time do
        described_class.fetch
        travel 2.hours
        expect(described_class.fetch).to eq("second")
      end
    end

    it "does not cache a token without an expiry" do
      allow(adc).to receive(:fetch_access_token!).and_return(token("first", expires_in: nil), token("second"))
      expect(described_class.fetch).to eq("first")
      expect(described_class.fetch).to eq("second")
    end

    it "reset! drops the cached token" do
      allow(adc).to receive(:fetch_access_token!).and_return(token("first"), token("second"))
      described_class.fetch
      described_class.reset!
      expect(described_class.fetch).to eq("second")
    end
  end

  describe "errors (never the key, the token or the original message)" do
    it "rejects an invalid service-account key without quoting it or falling back to ADC" do
      allow(Google::Auth).to receive(:get_application_default)
      ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = '{"private_key": "-----BEGIN SECRET-----'
      expect { described_class.fetch }.to raise_error(described_class::CredentialsError) { |e|
        expect(e.message).to include("GOOGLE_SERVICE_ACCOUNT_JSON is not a valid service account key")
        expect(e.message).not_to include("SECRET")
        expect(e.cause).to be_nil
      }
      expect(Google::Auth).not_to have_received(:get_application_default)
    end

    it "explains how to configure credentials when ADC finds none" do
      ENV.delete("GOOGLE_SERVICE_ACCOUNT_JSON")
      allow(Google::Auth).to receive(:get_application_default)
        .and_raise(Google::Auth::InitializationError, "Could not load the default credentials")
      expect { described_class.fetch }.to raise_error(described_class::CredentialsError) { |e|
        expect(e.message).to include("gcloud auth application-default login", "GOOGLE_SERVICE_ACCOUNT_JSON")
        expect(e.cause).to be_nil
      }
    end

    it "wraps a refused token request (e.g. expired ADC login) without its message, and caches nothing" do
      ENV.delete("GOOGLE_SERVICE_ACCOUNT_JSON")
      allow(Google::Auth).to receive(:get_application_default).and_return(adc)
      allow(adc).to receive(:fetch_access_token!)
        .and_raise(Signet::AuthorizationError, "invalid_grant: refresh-token-abc123")
      expect { described_class.fetch }.to raise_error(described_class::CredentialsError) { |e|
        expect(e.message).to include("application default credentials", "Signet::AuthorizationError")
        expect(e.message).not_to include("refresh-token-abc123")
        expect(e.cause).to be_nil
      }

      allow(adc).to receive(:fetch_access_token!).and_return(token("recovered"))
      expect(described_class.fetch).to eq("recovered")
    end

    it "wraps a refused token request for the service account the same way" do
      ENV["GOOGLE_SERVICE_ACCOUNT_JSON"] = '{"client_email":"x"}'
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(service_account)
      allow(service_account).to receive(:fetch_access_token!).and_raise(Signet::AuthorizationError, "invalid_grant")
      expect { described_class.fetch }.to raise_error(described_class::CredentialsError, /service account/)
    end
  end
end
