# frozen_string_literal: true

require "rails_helper"

RSpec.describe Media::SafeFetcher do
  let(:png) { File.binread(Rails.root.join("spec/fixtures/ai/garment_image.png")) }
  let(:jpeg) { File.binread(Rails.root.join("spec/fixtures/files/garment.jpg")) }

  it "blocks metadata hostnames" do
    expect {
      described_class.fetch("http://metadata.google.internal/latest/meta-data/")
    }.to raise_error(Media::UnsafeUrlError)
  end

  it "blocks file urls" do
    expect {
      described_class.fetch("file:///etc/passwd")
    }.to raise_error(Media::UnsafeUrlError)
  end

  it "fetches allowed public urls" do
    stub_request(:get, "https://example.com/image.jpg")
      .to_return(status: 200, body: png, headers: { "Content-Type" => "image/png" })

    image = described_class.fetch("https://example.com/image.jpg")
    expect(image.bytes).to be_present
    expect(image.mime_type).to be_present
  end

  describe "allowed requests" do
    it "returns the body and detects the type from the bytes, not the Content-Type header" do
      stub_request(:get, "https://images.example.com/shirt").to_return(status: 200, body: jpeg,
                                                                       headers: { "Content-Type" => "text/html" })
      image = described_class.fetch("https://images.example.com/shirt")
      expect(image.bytes).to eq(jpeg)
      expect(image.mime_type).to eq("image/jpeg")
    end

    it "follows a redirect to another public host" do
      stub_request(:get, "https://images.example.com/old").to_return(status: 302,
                                                                     headers: { "Location" => "https://cdn.example.com/new.jpg" })
      stub_request(:get, "https://cdn.example.com/new.jpg").to_return(status: 200, body: jpeg)
      expect(described_class.fetch("https://images.example.com/old").bytes).to eq(jpeg)
    end

    it "sends its own User-Agent" do
      stub = stub_request(:get, "https://images.example.com/a.jpg")
             .with(headers: { "User-Agent" => described_class::USER_AGENT }).to_return(status: 200, body: jpeg)
      described_class.fetch("https://images.example.com/a.jpg")
      expect(stub).to have_been_requested
    end
  end

  describe "SSRF protection (design doc 4.4)" do
    [
      "http://127.0.0.1/admin", "http://10.0.0.5/x.jpg", "http://172.16.1.1/x.jpg", "http://192.168.1.10/x.jpg",
      "http://169.254.169.254/latest/meta-data/", "http://0.0.0.0/x", "http://100.100.100.200/x",
      "http://[::1]/x", "http://[fc00::1]/x", "http://[fe80::1]/x", "http://[::ffff:127.0.0.1]/x"
    ].each do |url|
      it "refuses #{url}" do
        expect { described_class.fetch(url) }.to raise_error(Media::UnsafeUrlError)
        expect(a_request(:any, /.*/)).not_to have_been_made
      end
    end

    it "refuses a public-looking hostname that resolves to a private address" do
      FakeDns.map("internal.example.com", "10.0.0.7")
      expect { described_class.fetch("https://internal.example.com/x.jpg") }.to raise_error(Media::UnsafeUrlError)
      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "refuses a redirect to a private address" do
      stub_request(:get, "https://images.example.com/hop").to_return(status: 302,
                                                                     headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })
      expect { described_class.fetch("https://images.example.com/hop") }.to raise_error(Media::UnsafeUrlError)
      expect(a_request(:get, %r{169\.254\.169\.254})).not_to have_been_made
    end

    it "refuses a redirect to a blocked metadata hostname" do
      stub_request(:get, "https://images.example.com/hop").to_return(status: 301,
                                                                     headers: { "Location" => "http://metadata.google.internal/computeMetadata/v1/" })
      expect { described_class.fetch("https://images.example.com/hop") }.to raise_error(Media::UnsafeUrlError)
    end

    it "refuses a redirect to another scheme" do
      stub_request(:get, "https://images.example.com/hop").to_return(status: 302, headers: { "Location" => "ftp://images.example.com/x" })
      expect { described_class.fetch("https://images.example.com/hop") }.to raise_error(Media::UnsafeUrlError)
    end

    it "refuses a redirect to a non-default port" do
      stub_request(:get, "https://images.example.com/hop").to_return(status: 302,
                                                                     headers: { "Location" => "https://images.example.com:8443/x" })
      expect { described_class.fetch("https://images.example.com/hop") }.to raise_error(Media::UnsafeUrlError)
      expect(a_request(:get, %r{:8443})).not_to have_been_made
    end

    it "refuses credentials in the URL" do
      expect { described_class.fetch("https://user:pass@images.example.com/x.jpg") }.to raise_error(Media::UnsafeUrlError)
    end

    it "refuses non-default ports" do
      expect { described_class.fetch("http://images.example.com:6379/") }.to raise_error(Media::UnsafeUrlError)
    end

    it "refuses things that are not http(s) URLs" do
      [ "javascript:alert(1)", "gopher://images.example.com/", "//images.example.com/x.jpg", "", nil, 42 ].each do |url|
        expect { described_class.fetch(url) }.to raise_error(Media::UnsafeUrlError)
      end
    end
  end

  describe "download failures" do
    it "gives up after three redirects" do
      4.times do |i|
        stub_request(:get, "https://images.example.com/r#{i}").to_return(status: 302,
                                                                         headers: { "Location" => "https://images.example.com/r#{i + 1}" })
      end
      expect { described_class.fetch("https://images.example.com/r0") }.to raise_error(Media::FetchError)
    end

    [ 404, 403, 500, 503 ].each do |status|
      it "treats HTTP #{status} as a failed download" do
        stub_request(:get, "https://images.example.com/x.jpg").to_return(status: status, body: "nope")
        expect { described_class.fetch("https://images.example.com/x.jpg") }.to raise_error(Media::FetchError)
      end
    end

    it "stops reading a body larger than the limit" do
      stub_request(:get, "https://images.example.com/big.jpg").to_return(status: 200, body: "x" * 2_000)
      expect { described_class.fetch("https://images.example.com/big.jpg", max_bytes: 1_000) }
        .to raise_error(Media::FetchError) { |e| expect(e.user_message).to eq("Image is too large") }
    end

    it "refuses a declared Content-Length over the limit before reading" do
      stub_request(:get, "https://images.example.com/big.jpg")
        .to_return(status: 200, body: "x", headers: { "Content-Length" => 50.megabytes.to_s })
      expect { described_class.fetch("https://images.example.com/big.jpg") }
        .to raise_error(Media::FetchError) { |e| expect(e.user_message).to eq("Image is too large") }
    end

    it "maps timeouts to a failed download" do
      stub_request(:get, "https://images.example.com/slow.jpg").to_timeout
      expect { described_class.fetch("https://images.example.com/slow.jpg") }.to raise_error(Media::FetchError)
    end

    it "maps connection errors to a failed download" do
      stub_request(:get, "https://images.example.com/x.jpg").to_raise(Errno::ECONNREFUSED)
      expect { described_class.fetch("https://images.example.com/x.jpg") }.to raise_error(Media::FetchError)
    end

    it "treats a hostname that does not resolve as a failed download" do
      expect { described_class.fetch("https://nowhere.example.com/x.jpg") }.to raise_error(Media::FetchError)
    end

    describe "transient or permanent" do
      [ 408, 429, 500, 502, 503 ].each do |status|
        it "marks HTTP #{status} as worth retrying" do
          stub_request(:get, "https://images.example.com/x.jpg").to_return(status: status)
          expect { described_class.fetch("https://images.example.com/x.jpg") }.to raise_error(Media::TransientFetchError)
        end
      end

      [ 400, 403, 404, 410 ].each do |status|
        it "marks HTTP #{status} as permanent" do
          stub_request(:get, "https://images.example.com/x.jpg").to_return(status: status)
          expect { described_class.fetch("https://images.example.com/x.jpg") }
            .to raise_error(Media::FetchError) { |e| expect(e).not_to be_a(Media::TransientFetchError) }
        end
      end

      it "marks timeouts and connection errors as worth retrying" do
        stub_request(:get, "https://images.example.com/slow.jpg").to_timeout
        expect { described_class.fetch("https://images.example.com/slow.jpg") }.to raise_error(Media::TransientFetchError)
        stub_request(:get, "https://images.example.com/down.jpg").to_raise(SocketError)
        expect { described_class.fetch("https://images.example.com/down.jpg") }.to raise_error(Media::TransientFetchError)
      end

      it "marks an oversized body, unresolvable host and redirect loop as permanent" do
        stub_request(:get, "https://images.example.com/big.jpg").to_return(status: 200, body: "x" * 2_000)
        [ -> { described_class.fetch("https://images.example.com/big.jpg", max_bytes: 1_000) },
          -> { described_class.fetch("https://nowhere.example.com/x.jpg") } ].each do |call|
          expect(&call).to raise_error(Media::FetchError) { |e| expect(e).not_to be_a(Media::TransientFetchError) }
        end
      end
    end

    it "keeps the URL (and any token in it) out of error messages" do
      stub_request(:get, %r{images\.example\.com/x\.jpg}).to_return(status: 500)
      error = (described_class.fetch("https://images.example.com/x.jpg?token=SECRET123") rescue $!)
      expect(error).to be_a(Media::FetchError)
      expect([ error.message, error.user_message ].join(" ")).not_to include("SECRET123", "images.example.com")
    end
  end
end
