# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client::Vertex do
  let(:client) { described_class.new }
  let(:gemini) { %r{aiplatform.googleapis.com.*generateContent} }
  let(:imagen) { %r{aiplatform.googleapis.com.*:predict} }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  before do
    allow(Ai::GoogleToken).to receive(:fetch).and_return("token")
    ENV["GOOGLE_CLOUD_PROJECT"] = "test-project"
    ENV["GOOGLE_CLOUD_PROJECT_NUMBER"] = "123456789"
  end

  def google_error(code, status, message = "details", details: [])
    JSON.generate(error: { code: code, message: message, status: status, details: details })
  end

  def call_gemini = client.generate_json(kind: :garment_extraction, prompt: "hi", schema: { type: "object" })
  def call_imagen = client.generate_image(kind: :garment_image, prompt: "shirt")

  describe "successful responses (unchanged)" do
    it "parses generate_json responses" do
      stub_request(:post, gemini)
        .to_return(status: 200, body: JSON.generate(
          candidates: [ { content: { parts: [ { text: '{"items":[]}' } ] } } ]
        ), headers: json_headers)

      result = client.generate_json(kind: :garment_extraction, prompt: "hi", schema: { type: "object" })
      expect(result).to eq("items" => [])
      expect(AiCall.last.kind).to eq("garment_extraction")
    end

    it "logs a success as ok with its estimated cost and image counts" do
      stub_request(:post, imagen)
        .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("img") } ]),
                   headers: json_headers)
      call_imagen
      expect(AiCall.sole).to have_attributes(status: "ok", kind: "garment_image", model: "imagen-4.0-fast-generate-001",
                                             images_out: 1, error_class: nil, est_cost_cents: 2.0)
    end

    it "returns plain text, and an empty text when Gemini gives none without a safety reason" do
      stub_request(:post, gemini).to_return(
        { status: 200, body: JSON.generate(candidates: [ { content: { parts: [ { text: "Hello" } ] } } ]) },
        { status: 200, body: JSON.generate(candidates: [ { finishReason: "STOP", content: { parts: [] } } ]) }
      )
      expect(client.generate_text(kind: :outfit_explanation, prompt: "explain")).to eq("Hello")
      expect(client.generate_text(kind: :outfit_explanation, prompt: "explain")).to eq("")
    end

    it "calls grounded generation" do
      stub_request(:post, %r{discoveryengine.googleapis.com.*generateGroundedContent})
        .to_return(status: 200, body: JSON.generate(
          candidates: [ { content: { parts: [ { text: "Nice outfit." } ] } } ]
        ), headers: json_headers)

      text = client.grounded_text(
        kind: :outfit_explanation,
        prompt: "Explain",
        facts: [ { text: "Top: shirt", title: "top" } ]
      )
      expect(text).to eq("Nice outfit.")
    end

    it "returns ranked records" do
      stub_request(:post, %r{discoveryengine.googleapis.com.*rank})
        .to_return(status: 200, body: JSON.generate(records: [ { id: "0", score: 0.9 } ]), headers: json_headers)

      out = client.rank(kind: :search_rank, query: "shirt", records: [ { id: "0", title: "A", content: "B" } ])
      expect(out.first[:score]).to eq(0.9)
    end

    it "returns image bytes from Imagen predict" do
      stub_request(:post, imagen)
        .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("img") } ]),
                   headers: json_headers)

      img = client.generate_image(kind: :garment_image, prompt: "shirt")
      expect(img.bytes).to eq("img")
    end

    it "calls generate_image_with_subject" do
      stub_request(:post, imagen)
        .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("subj") } ]),
                   headers: json_headers)

      img = client.generate_image_with_subject(
        kind: :outfit_preview_subject,
        prompt: "outfit",
        subject: Ai::Image.new(bytes: "face", mime_type: "image/jpeg")
      )
      expect(img.bytes).to eq("subj")
    end

    it "calls generate_image_multimodal" do
      stub_request(:post, gemini)
        .to_return(status: 200, body: JSON.generate(
          candidates: [ { content: { parts: [ { inlineData: { mimeType: "image/png", data: Base64.strict_encode64("z") } } ] } } ]
        ), headers: json_headers)

      img = client.generate_image_multimodal(
        kind: :outfit_preview_gemini,
        prompt: "draw",
        images: [ Ai::Image.new(bytes: "a", mime_type: "image/jpeg") ]
      )
      expect(img.bytes).to eq("z")
    end

    it "uses a 10-second open timeout, keeps the 120-second request timeout and has no retry middleware" do
      connection = client.send(:connection)
      expect([ connection.options.open_timeout, connection.options.timeout ]).to eq([ 10, 120 ])
      expect(connection.builder.handlers.map(&:name)).not_to include("Faraday::Retry::Middleware")
    end
  end

  describe "HTTP error categories" do
    {
      [ 400, "INVALID_ARGUMENT" ] => Ai::InvalidRequestError,
      [ 401, "UNAUTHENTICATED" ] => Ai::AuthenticationError,
      [ 403, "PERMISSION_DENIED" ] => Ai::AuthenticationError,
      [ 404, "NOT_FOUND" ] => Ai::NotFoundError,
      [ 408, "DEADLINE_EXCEEDED" ] => Ai::TransientError,
      [ 413, "INVALID_ARGUMENT" ] => Ai::InvalidRequestError,
      [ 429, "RESOURCE_EXHAUSTED" ] => Ai::RateLimitedError,
      [ 500, "INTERNAL" ] => Ai::TransientError,
      [ 502, nil ] => Ai::TransientError,
      [ 503, "UNAVAILABLE" ] => Ai::TransientError,
      [ 504, "DEADLINE_EXCEEDED" ] => Ai::TransientError
    }.each do |(code, google_status), klass|
      it "maps #{code} to #{klass} (Gemini and Imagen) with only the validated status in the message" do
        body = google_status ? google_error(code, google_status) : "<html>Bad Gateway</html>"
        stub_request(:post, gemini).to_return(status: code, body: body)
        stub_request(:post, imagen).to_return(status: code, body: body)

        [ -> { call_gemini }, -> { call_imagen } ].each do |call|
          expect { call.call }.to raise_error(klass) { |e|
            expect(e.class).to eq(klass)
            expect(e.message).to eq([ "Vertex HTTP #{code}", google_status ].compact.join(" "))
            expect([ e.http_status, e.google_status ]).to eq([ code, google_status ])
          }
        end
      end
    end

    it "treats 429 as a TransientError, so the jobs' retry_on covers it" do
      stub_request(:post, gemini).to_return(status: 429, body: "rate limited")
      expect { client.generate_text(kind: :outfit_explanation, prompt: "explain") }.to raise_error(Ai::TransientError)
    end

    it "classifies a 404 with an HTML body by its status" do
      stub_request(:post, imagen).to_return(status: 404, body: "<!DOCTYPE html><title>Not Found</title>")
      expect { call_imagen }.to raise_error(Ai::NotFoundError, "Vertex HTTP 404")
    end

    it "ignores a Google status that is not a canonical code" do
      stub_request(:post, gemini).to_return(status: 403, body: google_error(403, "token tok-123 rejected"))
      expect { call_gemini }.to raise_error(Ai::AuthenticationError) { expect(_1.google_status).to be_nil }
    end

    it "maps timeouts and connection failures to TransientError" do
      stub_request(:post, gemini).to_timeout
      expect { call_gemini }.to raise_error(Ai::TransientError, /\AVertex request failed \(Faraday::(TimeoutError|ConnectionFailed)\)\z/)
      stub_request(:post, imagen).to_raise(Faraday::ConnectionFailed.new("Failed to open TCP connection"))
      expect { call_imagen }.to raise_error(Ai::TransientError, "Vertex request failed (Faraday::ConnectionFailed)")
    end

    it "maps errors from grounded generation and ranking the same way" do
      stub_request(:post, /discoveryengine/).to_return(status: 403, body: google_error(403, "PERMISSION_DENIED"))
      expect { client.grounded_text(kind: :outfit_explanation, prompt: "x", facts: []) }.to raise_error(Ai::AuthenticationError)
      expect { client.rank(kind: :search_rank, query: "x", records: []) }.to raise_error(Ai::AuthenticationError)
    end
  end

  describe "safety responses (ContentBlockedError only with an explicit indicator)" do
    it "Gemini: a blocked prompt (promptFeedback.blockReason)" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(promptFeedback: { blockReason: "SAFETY" }))
      expect { call_gemini }.to raise_error(Ai::ContentBlockedError)
      expect(AiCall.sole.status).to eq("blocked")
    end

    %w[SAFETY PROHIBITED_CONTENT IMAGE_SAFETY].each do |reason|
      it "Gemini: a candidate withheld with finishReason #{reason}" do
        stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(candidates: [ { finishReason: reason } ]))
        expect { call_gemini }.to raise_error(Ai::ContentBlockedError)
        expect { client.generate_text(kind: :outfit_explanation, prompt: "x") }.to raise_error(Ai::ContentBlockedError)
      end
    end

    it "Gemini multimodal: no image with a safety finishReason is blocked, without one it is invalid" do
      images = [ Ai::Image.new(bytes: "a", mime_type: "image/jpeg") ]
      stub_request(:post, gemini).to_return(
        { status: 200, body: JSON.generate(candidates: [ { finishReason: "IMAGE_SAFETY" } ]) },
        { status: 200, body: JSON.generate(candidates: [ { finishReason: "STOP", content: { parts: [ { text: "no" } ] } } ]) }
      )
      expect { client.generate_image_multimodal(kind: :outfit_preview_gemini, prompt: "x", images:) }
        .to raise_error(Ai::ContentBlockedError)
      expect { client.generate_image_multimodal(kind: :outfit_preview_gemini, prompt: "x", images:) }
        .to raise_error(Ai::InvalidResponseError, "No image in response")
    end

    it "Imagen: raiFilteredReason at the top or on the prediction" do
      stub_request(:post, imagen).to_return(
        { status: 200, body: JSON.generate(raiFilteredReason: "filtered") },
        { status: 200, body: JSON.generate(predictions: [ { raiFilteredReason: "filtered" } ]) }
      )
      2.times { expect { call_imagen }.to raise_error(Ai::ContentBlockedError) }
      expect(AiCall.pluck(:status)).to eq(%w[blocked blocked])
    end

    it "HTTP 400 with a structured safety ErrorInfo reason is blocked" do
      details = [ { "@type" => "type.googleapis.com/google.rpc.ErrorInfo", reason: "RAI_FILTERED", domain: "aiplatform.googleapis.com" } ]
      stub_request(:post, imagen).to_return(status: 400, body: google_error(400, "INVALID_ARGUMENT", details:))
      expect { call_imagen }.to raise_error(Ai::ContentBlockedError, "Vertex HTTP 400 INVALID_ARGUMENT")
    end

    it "HTTP 400 is not blocked because of words in the free-text message" do
      message = "The prompt violates Google's Responsible AI practices and safety usage guidelines"
      details = [ { "@type" => "type.googleapis.com/google.rpc.BadRequest", reason: "SAFETY" },
                  { "@type" => "type.googleapis.com/google.rpc.ErrorInfo", reason: "not an enum: SAFETY" } ]
      stub_request(:post, imagen).to_return(status: 400, body: google_error(400, "INVALID_ARGUMENT", message, details:))
      expect { call_imagen }.to raise_error(Ai::InvalidRequestError)
    end
  end

  describe "invalid or malformed responses" do
    it "Imagen: empty predictions without a safety indicator are an invalid response, not a block" do
      stub_request(:post, imagen).to_return(status: 200, body: JSON.generate(predictions: []), headers: json_headers)
      expect { call_imagen }.to raise_error(Ai::InvalidResponseError)
      expect(AiCall.sole.status).to eq("error")
    end

    it "Gemini: output cut off at MAX_TOKENS" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(
        candidates: [ { finishReason: "MAX_TOKENS", content: { parts: [ { text: '{"items":[{"name":' } ] } } ]
      ))
      expect { call_gemini }.to raise_error(Ai::InvalidResponseError, "Gemini output is not valid JSON (finishReason MAX_TOKENS)")
    end

    it "Gemini: empty output without a safety reason" do
      stub_request(:post, gemini).to_return(status: 200, body: JSON.generate(candidates: [ { finishReason: "STOP" } ]))
      expect { call_gemini }.to raise_error(Ai::InvalidResponseError)
    end

    it "a 2xx body that is not a JSON object" do
      stub_request(:post, gemini).to_return({ status: 200, body: "<html>ok</html>" }, { status: 200, body: "[1,2]" })
      2.times { expect { call_gemini }.to raise_error(Ai::InvalidResponseError, /body is not a JSON object/) }
    end
  end

  describe "failure logging (ai_calls and the Rails log)" do
    let(:log) { StringIO.new }

    before { allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log)) }

    it "writes exactly one non-billable row per failed attempt, with status, class, latency, kind and model" do
      stub_request(:post, imagen).to_return(status: 403, body: google_error(403, "PERMISSION_DENIED"))
      user = create(:user)
      expect { client.generate_image(kind: :garment_image, prompt: "shirt", user:) }.to raise_error(Ai::AuthenticationError)

      expect(AiCall.sole).to have_attributes(
        status: "error", error_class: "Ai::AuthenticationError", kind: "garment_image",
        model: "imagen-4.0-fast-generate-001", user_id: user.id, images_in: 0, images_out: 0, est_cost_cents: 0
      )
      expect(AiCall.sole.latency_ms).to be >= 0
    end

    it "logs one structured diagnostic line" do
      stub_request(:post, gemini).to_return(status: 404, body: google_error(404, "NOT_FOUND"))
      expect { call_gemini }.to raise_error(Ai::NotFoundError)
      expect(log.string.lines.grep(/call failed/)).to contain_exactly(
        a_string_matching(/kind=garment_extraction model=gemini-2.5-flash http=404 google_status=NOT_FOUND error=Ai::NotFoundError latency_ms=\d+/)
      )
    end

    it "logs network failures as one error row with http=none" do
      stub_request(:post, gemini).to_raise(Faraday::ConnectionFailed.new("Failed to open TCP connection"))
      expect { call_gemini }.to raise_error(Ai::TransientError)
      expect(AiCall.sole).to have_attributes(status: "error", error_class: "Ai::TransientError")
      expect(log.string).to include("http=none google_status=none")
    end

    it "does not let failed attempts use up the daily image cap or the budget" do
      with_env("AI_DAILY_IMAGE_LIMIT" => "1", "AI_DAILY_BUDGET_CENTS" => "1") do
        user = create(:user)
        stub_request(:post, imagen).to_return(
          { status: 500, body: google_error(500, "INTERNAL") },
          { status: 503, body: google_error(503, "UNAVAILABLE") },
          { status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64("img") } ]) }
        )
        2.times { expect { client.generate_image(kind: :garment_image, prompt: "s", user:) }.to raise_error(Ai::TransientError) }
        expect(client.generate_image(kind: :garment_image, prompt: "s", user:).bytes).to eq("img")
        expect(AiCall.order(:created_at).pluck(:status, :est_cost_cents)).to eq([ [ "error", 0 ], [ "error", 0 ], [ "ok", 2.0 ] ])
      end
    end

    it "makes no request and writes no row for our own quota and kill-switch refusals" do
      create(:ai_call, est_cost_cents: 2000, created_at: Time.current)
      expect { client.generate_text(kind: :outfit_explanation, prompt: "x", user: create(:user)) }
        .to raise_error(Ai::QuotaExceededError)
      with_env("AI_IMAGE_GEN_ENABLED" => "false") { expect { call_imagen }.to raise_error(Ai::DisabledError) }
      expect(AiCall.count).to eq(1) # the seeded row only
      expect(a_request(:post, /googleapis/)).not_to have_been_made
    end

    it "writes no row when credentials fail before any request" do
      allow(Ai::GoogleToken).to receive(:fetch).and_raise(Ai::GoogleToken::CredentialsError, "No Google credentials")
      expect { call_gemini }.to raise_error(Ai::GoogleToken::CredentialsError)
      expect(AiCall.count).to eq(0)
    end
  end

  describe "sensitive data" do
    let(:log) { StringIO.new }
    let(:secrets) { [ "SECRET-PROMPT", "IMG-SECRET", Base64.strict_encode64("IMG-SECRET"), "tok-SECRET", "Bearer" ] }

    before do
      allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log))
      allow(Ai::GoogleToken).to receive(:fetch).and_return("tok-SECRET")
    end

    [ 400, 401, 403, 404, 429, 500 ].each do |code|
      it "keeps prompts, images and the token out of the error, the log and ai_calls (HTTP #{code})" do
        echo = "Bearer tok-SECRET SECRET-PROMPT #{Base64.strict_encode64('IMG-SECRET')} IMG-SECRET"
        body = JSON.generate(error: { code:, status: "INVALID_ARGUMENT", message: echo,
                                      details: [ { "@type" => "type.googleapis.com/google.rpc.BadRequest", echo: } ] })
        stub_request(:post, gemini).to_return(status: code, body: body)

        error = nil
        begin
          client.generate_json(kind: :garment_extraction, prompt: "SECRET-PROMPT", schema: { type: "object" },
                               images: [ Ai::Image.new(bytes: "IMG-SECRET", mime_type: "image/jpeg") ])
        rescue Ai::Error => e
          error = e
        end
        expect(error).to be_a(Ai::Error)
        surfaces = [ error.message, error.full_message, error.inspect, log.string, AiCall.sole.attributes.to_json ]
        secrets.each { |secret| surfaces.each { expect(_1).not_to include(secret) } }
      end
    end
  end

  describe "retries (none at the HTTP level; jobs own them)" do
    [ [ 429, "RESOURCE_EXHAUSTED" ], [ 500, "INTERNAL" ], [ 503, "UNAVAILABLE" ] ].each do |code, status|
      it "sends exactly one request for HTTP #{code}" do
        stub_request(:post, imagen).to_return(status: code, body: google_error(code, status))
        expect { call_imagen }.to raise_error(Ai::TransientError)
        expect(a_request(:post, imagen)).to have_been_made.once
        expect(AiCall.count).to eq(1)
      end
    end

    it "sends exactly one request when the connection times out" do
      stub_request(:post, gemini).to_timeout
      expect { call_gemini }.to raise_error(Ai::TransientError)
      expect(a_request(:post, gemini)).to have_been_made.once
    end
  end
end
