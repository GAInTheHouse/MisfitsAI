# frozen_string_literal: true

require "rails_helper"
require "active_storage/service/gcs_service"

# config/storage.yml, google service: credentials from GOOGLE_SERVICE_ACCOUNT_JSON or Application Default Credentials,
# and optional keyless signing (GCS_SIGNING_SERVICE_ACCOUNT -> iam: true, gsa_email). Everything here is offline:
# keys are generated locally, the IAM Credentials call is stubbed and WebMock blocks the network.
RSpec.describe "config/storage.yml" do
  let(:key_email) { "fake-key@test-project.iam.gserviceaccount.com" }
  let(:signer_email) { "misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com" }
  let(:rsa) { OpenSSL::PKey::RSA.new(2048) }
  let(:key_json) do
    { type: "service_account", project_id: "test-project", private_key_id: "1", private_key: rsa.to_pem,
      client_email: key_email, client_id: "1", token_uri: "https://oauth2.googleapis.com/token" }.to_json
  end
  let(:base_env) { { "GOOGLE_CLOUD_PROJECT" => "misfitai-512403", "GCS_BUCKET" => "misfitai-dev-images-2026" } }

  def rendered(env)
    with_env(base_env.merge(env)) { ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage.yml")) }
  end

  def google(env) = rendered(env).fetch("google")

  def service(env)
    config = rendered(env)
    ActiveStorage::Service::Configurator.build(:google, config)
  end

  def signed_url(service)
    service.url("integration-checks/x.jpg", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("x.jpg"),
                                             content_type: "image/jpeg", disposition: :inline)
  end

  # Offline stand-ins for what ADC would find: a user login (no private key) or a service account (with one).
  def user_adc
    Google::Cloud::Storage::Credentials.new({ "type" => "authorized_user", "client_id" => "id", "client_secret" => "secret",
                                              "refresh_token" => "refresh", "quota_project_id" => "misfitai-512403" })
  end

  describe "rendering" do
    {
      "absent JSON, absent signer" => [ { "GOOGLE_SERVICE_ACCOUNT_JSON" => nil, "GCS_SIGNING_SERVICE_ACCOUNT" => nil }, :adc, false ],
      "blank JSON, absent signer" => [ { "GOOGLE_SERVICE_ACCOUNT_JSON" => "", "GCS_SIGNING_SERVICE_ACCOUNT" => nil }, :adc, false ],
      "whitespace JSON, blank signer" => [ { "GOOGLE_SERVICE_ACCOUNT_JSON" => "  \n", "GCS_SIGNING_SERVICE_ACCOUNT" => "  " }, :adc, false ],
      "JSON key, absent signer" => [ { "GCS_SIGNING_SERVICE_ACCOUNT" => nil }, :key, false ],
      "absent JSON, signer" => [ { "GOOGLE_SERVICE_ACCOUNT_JSON" => nil }, :adc, true ],
      "blank JSON, signer" => [ { "GOOGLE_SERVICE_ACCOUNT_JSON" => "" }, :adc, true ],
      "JSON key and signer" => [ {}, :key, true ]
    }.each do |label, (env, credentials, signing)|
      it "#{label}: #{credentials == :adc ? 'no credentials (ADC)' : 'the JSON key'}, #{signing ? 'IAM signing' : 'no IAM signing'}" do
        env = { "GOOGLE_SERVICE_ACCOUNT_JSON" => key_json, "GCS_SIGNING_SERVICE_ACCOUNT" => " #{signer_email} " }.merge(env)
        config = google(env)

        expect(config).to include("service" => "GCS", "project" => "misfitai-512403", "bucket" => "misfitai-dev-images-2026")
        if credentials == :adc
          expect(config).not_to have_key("credentials")
        else
          expect(config["credentials"]).to include("type" => "service_account", "client_email" => key_email,
                                                   "private_key" => rsa.to_pem)
        end
        if signing
          expect(config).to include("iam" => true, "gsa_email" => signer_email) # surrounding whitespace removed
        else
          expect(config.keys).not_to include("iam", "gsa_email")
        end
      end
    end

    it "leaves the local and test services unchanged" do
      config = rendered({})
      expect(config["test"]).to eq("service" => "Disk", "root" => Rails.root.join("tmp/storage").to_s)
      expect(config["local"]).to eq("service" => "Disk", "root" => Rails.root.join("storage").to_s)
    end
  end

  describe "what reaches Google::Cloud::Storage.new" do
    def client_kwargs(env)
      captured = nil
      allow(Google::Cloud::Storage).to receive(:new) { |**kwargs| captured = kwargs }
      service(env).send(:client)
      captured
    end

    it "passes no credentials when the JSON is blank or absent, so the library uses ADC" do
      [ nil, "", "   " ].each do |json|
        kwargs = client_kwargs("GOOGLE_SERVICE_ACCOUNT_JSON" => json, "GCS_SIGNING_SERVICE_ACCOUNT" => signer_email)
        expect(kwargs).to eq(project: "misfitai-512403")
      end
    end

    it "passes the parsed JSON key, and never the iam or gsa_email settings" do
      kwargs = client_kwargs("GOOGLE_SERVICE_ACCOUNT_JSON" => key_json, "GCS_SIGNING_SERVICE_ACCOUNT" => signer_email)
      expect(kwargs.keys).to contain_exactly(:project, :credentials)
      expect(kwargs[:credentials]).to include(client_email: key_email, type: "service_account")
    end
  end

  describe "the real storage client and signer (offline)" do
    let(:iam) { instance_double(Google::Apis::IamcredentialsV1::IAMCredentialsService) }
    let(:signed_resources) { [] }

    before do
      allow(Google::Auth).to receive(:get_application_default).and_return(Object.new) # the ADC used to call signBlob
      allow(Google::Apis::IamcredentialsV1::IAMCredentialsService).to receive(:new).and_return(iam)
      allow(iam).to receive(:authorization).and_return(nil)
      allow(iam).to receive(:authorization=)
      allow(iam).to receive(:sign_service_account_blob) do |resource, _request|
        signed_resources << resource
        Google::Apis::IamcredentialsV1::SignBlobResponse.new(signed_blob: "iam-signature".b)
      end
    end

    it "uses the library's default credentials (ADC) when the JSON is blank" do
      allow(Google::Cloud::Storage::Credentials).to receive(:default).and_return(user_adc)
      client = service("GOOGLE_SERVICE_ACCOUNT_JSON" => "", "GCS_SIGNING_SERVICE_ACCOUNT" => nil).send(:client)
      expect(Google::Cloud::Storage::Credentials).to have_received(:default)
      expect(client.project_id).to eq("misfitai-512403")
    end

    it "without a signing account, user ADC cannot sign (the check 6 failure)" do
      allow(Google::Cloud::Storage::Credentials).to receive(:default).and_return(user_adc)
      gcs = service("GOOGLE_SERVICE_ACCOUNT_JSON" => "", "GCS_SIGNING_SERVICE_ACCOUNT" => nil)
      expect { signed_url(gcs) }.to raise_error(Google::Cloud::Storage::SignedUrlUnavailable)
      expect(iam).not_to have_received(:sign_service_account_blob)
    end

    it "with a signing account and user ADC, signs through IAM signBlob as that account" do
      allow(Google::Cloud::Storage::Credentials).to receive(:default).and_return(user_adc)
      url = signed_url(service("GOOGLE_SERVICE_ACCOUNT_JSON" => "", "GCS_SIGNING_SERVICE_ACCOUNT" => signer_email))
      query = Rack::Utils.parse_query(URI.parse(url).query)
      expect(query["GoogleAccessId"]).to eq(signer_email)
      expect(query["Signature"]).to eq(Base64.strict_encode64("iam-signature"))
      expect(signed_resources).to eq([ "projects/-/serviceAccounts/#{signer_email}" ])
      expect(Google::Auth).to have_received(:get_application_default).with([ "https://www.googleapis.com/auth/iam" ])
    end

    it "with a JSON key and no signing account, signs locally with the key's private key, as before" do
      url = signed_url(service("GOOGLE_SERVICE_ACCOUNT_JSON" => key_json, "GCS_SIGNING_SERVICE_ACCOUNT" => nil))
      query = Rack::Utils.parse_query(URI.parse(url).query)
      expect(query["GoogleAccessId"]).to eq(key_email)
      expect(query["Signature"]).to be_present
      expect(iam).not_to have_received(:sign_service_account_blob)
    end

    it "with both set, the client uses the key but signing goes through IAM with ADC (not the key)" do
      gcs = service("GOOGLE_SERVICE_ACCOUNT_JSON" => key_json, "GCS_SIGNING_SERVICE_ACCOUNT" => signer_email)
      expect(gcs.send(:client).service.credentials.issuer).to eq(key_email)
      query = Rack::Utils.parse_query(URI.parse(signed_url(gcs)).query)
      expect(query["GoogleAccessId"]).to eq(signer_email)
      expect(Google::Auth).to have_received(:get_application_default)
    end
  end
end
