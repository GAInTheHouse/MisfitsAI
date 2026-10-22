# frozen_string_literal: true

require "rails_helper"
require "vips"

# Garment product images through a Gemini image model (GARMENT_IMAGE_MODEL, default gemini-2.5-flash-image), after
# Google discontinued the Imagen GA endpoints. Stubbed HTTP (WebMock), no network.
RSpec.describe Ai::Client::Vertex, "Gemini garment images" do
  let(:client) { described_class.new }
  let(:gemini_url) { "https://us-central1-aiplatform.googleapis.com/v1/projects/test-project/locations/us-central1/publishers/google/models/gemini-2.5-flash-image:generateContent" }
  let(:gemini) { %r{aiplatform.googleapis.com.*/models/gemini-2\.5-flash-image:generateContent} }
  let(:prompt) { "Professional e-commerce product photo of a single garment. Garment category: top." }
  let(:png) { Vips::Image.black(8, 8).new_from_image([ 255, 255, 255 ]).cast(:uchar).pngsave_buffer }
  let(:jpeg) { Vips::Image.black(8, 8).new_from_image([ 10, 20, 30 ]).cast(:uchar).jpegsave_buffer }
  let(:webp) { Vips::Image.black(8, 8).new_from_image([ 30, 60, 90 ]).cast(:uchar).webpsave_buffer }
  # A noisy image, so its compressed data is long enough to truncate or corrupt in the middle.
  let(:noisy_png) do
    band = -> { Vips::Image.gaussnoise(64, 48, sigma: 40, mean: 128).cast(:uchar) }
    band.call.bandjoin([ band.call, band.call ]).pngsave_buffer
  end

  before do
    allow(Ai::GoogleToken).to receive(:fetch).and_return("token")
    ENV["GOOGLE_CLOUD_PROJECT"] = "test-project"
  end

  around do |example|
    original = ENV.fetch("GARMENT_IMAGE_MODEL", nil)
    ENV.delete("GARMENT_IMAGE_MODEL") # the default applies unless an example sets it
    example.run
  ensure
    original.nil? ? ENV.delete("GARMENT_IMAGE_MODEL") : ENV["GARMENT_IMAGE_MODEL"] = original
  end

  def image_part(bytes, mime = "image/png") = { inlineData: { mimeType: mime, data: Base64.strict_encode64(bytes) } }
  def reply(parts, finish: "STOP") = JSON.generate(candidates: [ { finishReason: finish, content: { role: "model", parts: } } ])
  def generate(**opts) = client.generate_image(kind: :garment_image, prompt: prompt, **opts)

  describe "request" do
    it "calls generateContent on gemini-2.5-flash-image by default, with the prompt, TEXT+IMAGE and the aspect ratio" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      generate

      expect(a_request(:post, gemini_url).with { |req|
        JSON.parse(req.body) == {
          "contents" => [ { "role" => "user", "parts" => [ { "text" => prompt } ] } ],
          "generationConfig" => { "responseModalities" => %w[TEXT IMAGE], "imageConfig" => { "aspectRatio" => "1:1" } }
        } && req.headers["Authorization"] == "Bearer token"
      }).to have_been_made.once
      expect(a_request(:post, /:predict/)).not_to have_been_made
    end

    it "passes the aspect ratio through" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      generate(aspect_ratio: "3:4")
      expect(a_request(:post, gemini).with { JSON.parse(_1.body).dig("generationConfig", "imageConfig", "aspectRatio") == "3:4" })
        .to have_been_made.once
    end

    it "sends no Imagen-only parameters" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      generate
      expect(a_request(:post, gemini).with { |req| !req.body.match?(/personGeneration|addWatermark|outputOptions|instances|sampleCount/) })
        .to have_been_made.once
    end
  end

  describe "model selection and backward compatibility" do
    it "uses another Gemini image model from GARMENT_IMAGE_MODEL" do
      with_env("GARMENT_IMAGE_MODEL" => "gemini-3.1-flash-image") do
        stub_request(:post, %r{/models/gemini-3\.1-flash-image:generateContent}).to_return(status: 200, body: reply([ image_part(png) ]))
        generate
        expect(AiCall.sole.model).to eq("gemini-3.1-flash-image")
      end
    end

    it "keeps the unchanged Imagen :predict request when GARMENT_IMAGE_MODEL names an Imagen model" do
      with_env("GARMENT_IMAGE_MODEL" => "imagen-4.0-fast-generate-001") do
        stub_request(:post, %r{/models/imagen-4\.0-fast-generate-001:predict})
          .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64(png) } ]))
        expect(generate.bytes).to eq(png)
        expect(a_request(:post, /:predict/).with { |req|
          JSON.parse(req.body) == {
            "instances" => [ { "prompt" => prompt } ],
            "parameters" => { "sampleCount" => 1, "aspectRatio" => "1:1", "personGeneration" => "allow_adult",
                              "addWatermark" => true, "outputOptions" => { "mimeType" => "image/png" } }
          }
        }).to have_been_made.once
      end
    end

    it "leaves other image kinds (Phase 4 avatar) on IMAGEN_MODEL" do
      with_env("IMAGEN_MODEL" => "imagen-4.0-fast-generate-001") do
        stub_request(:post, %r{/models/imagen-4\.0-fast-generate-001:predict})
          .to_return(status: 200, body: JSON.generate(predictions: [ { bytesBase64Encoded: Base64.strict_encode64(png) } ]))
        client.generate_image(kind: :avatar_portrait, prompt: "portrait")
        expect(a_request(:post, /generateContent/)).not_to have_been_made
      end
    end
  end

  describe "decoding" do
    it "returns PNG bytes with their MIME type" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      image = generate
      expect([ image.bytes, image.mime_type ]).to eq([ png, "image/png" ])
    end

    it "respects a JPEG MIME type" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(jpeg, "image/jpeg") ]))
      image = generate
      expect([ image.bytes, image.mime_type ]).to eq([ jpeg, "image/jpeg" ])
    end

    it "uses the type detected from the bytes when the declared MIME type is missing or wrong" do
      stub_request(:post, gemini).to_return(
        { status: 200, body: reply([ { inlineData: { data: Base64.strict_encode64(png) } } ]) },
        { status: 200, body: reply([ image_part(png, "text/html") ]) },
        { status: 200, body: reply([ image_part(png, "image/jpeg") ]) }
      )
      3.times { expect(generate.mime_type).to eq("image/png") }
    end

    it "accepts a valid WebP image" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(webp, "image/webp") ]))
      image = generate
      expect([ image.bytes, image.mime_type ]).to eq([ webp, "image/webp" ])
    end

    it "takes the image from a mixed text-and-image response" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ { text: "Here is your shirt." }, image_part(jpeg, "image/jpeg"),
                                                                       { text: "Anything else?" } ]))
      expect(generate.bytes).to eq(jpeg)
    end

    it "produces bytes ImageNormalizer turns into the 512 square JPEG" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      out = Vips::Image.new_from_buffer(Media::ImageNormalizer.to_square_jpeg(generate.bytes, size: 512), "")
      expect([ out.width, out.height ]).to eq([ 512, 512 ])
    end
  end

  describe "safety, text-only and malformed responses" do
    {
      "finishReason IMAGE_SAFETY" => -> { JSON.generate(candidates: [ { finishReason: "IMAGE_SAFETY" } ]) },
      "finishReason IMAGE_PROHIBITED_CONTENT" => -> { JSON.generate(candidates: [ { finishReason: "IMAGE_PROHIBITED_CONTENT" } ]) },
      "finishReason SAFETY with text only" => -> { JSON.generate(candidates: [ { finishReason: "SAFETY", content: { parts: [ { text: "no" } ] } } ]) },
      "promptFeedback.blockReason" => -> { JSON.generate(promptFeedback: { blockReason: "PROHIBITED_CONTENT" }) }
    }.each do |label, body|
      it "raises ContentBlockedError and logs blocked for #{label}" do
        stub_request(:post, gemini).to_return(status: 200, body: instance_exec(&body))
        expect { generate }.to raise_error(Ai::ContentBlockedError)
        expect(AiCall.sole).to have_attributes(status: "blocked", error_class: "Ai::ContentBlockedError", est_cost_cents: 0, images_out: 0)
      end
    end

    {
      "a text-only refusal (STOP)" => -> { reply([ { text: "I can't create that image." } ]) },
      "finishReason NO_IMAGE" => -> { JSON.generate(candidates: [ { finishReason: "NO_IMAGE", content: { parts: [ { text: "x" } ] } } ]) },
      "finishReason IMAGE_OTHER" => -> { JSON.generate(candidates: [ { finishReason: "IMAGE_OTHER" } ]) },
      "inlineData without data" => -> { reply([ { inlineData: { mimeType: "image/png" } } ]) },
      "inlineData with invalid base64" => -> { reply([ { inlineData: { mimeType: "image/png", data: "%%%not-base64%%%" } } ]) },
      "candidates that are not a list" => -> { JSON.generate(candidates: "oops") },
      "content that is not an object" => -> { JSON.generate(candidates: [ { content: "oops" } ]) },
      "no candidates" => -> { JSON.generate({}) }
    }.each do |label, body|
      it "raises InvalidResponseError and logs error for #{label}" do
        stub_request(:post, gemini).to_return(status: 200, body: instance_exec(&body))
        expect { generate }.to raise_error(Ai::InvalidResponseError)
        expect(AiCall.sole).to have_attributes(status: "error", error_class: "Ai::InvalidResponseError", est_cost_cents: 0, images_out: 0)
      end
    end
  end

  describe "image validation (garment path)" do
    def corrupt(bytes)
      bytes.dup.tap { |b| (b.bytesize / 2...(b.bytesize / 2 + 40)).each { |i| b.setbyte(i, b.getbyte(i) ^ 0xFF) } }
    end

    {
      "text bytes declared as PNG" => -> { image_part("this is not an image", "image/png") },
      "a GIF" => -> { image_part("GIF89a\x01\x00\x01\x00\x80\x00\x00".b + ("\x00" * 20).b, "image/gif") },
      "an SVG" => -> { image_part(%(<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>), "image/svg+xml") },
      "a PNG truncated to its header" => -> { image_part(noisy_png[0, 40]) },
      "a PNG truncated halfway" => -> { image_part(noisy_png[0, noisy_png.bytesize / 2]) },
      "a PNG with corrupt data" => -> { image_part(corrupt(noisy_png)) },
      "a JPEG truncated halfway" => -> { image_part(jpeg[0, jpeg.bytesize / 2], "image/jpeg") }
    }.each do |label, part|
      it "rejects #{label} as InvalidResponseError with exactly one error row and no success row" do
        stub_request(:post, gemini).to_return(status: 200, body: reply([ instance_exec(&part) ]))
        expect { generate(user: create(:user)) }.to raise_error(Ai::InvalidResponseError)
        expect(AiCall.count).to eq(1)
        expect(AiCall.sole).to have_attributes(status: "error", error_class: "Ai::InvalidResponseError", images_out: 0,
                                               est_cost_cents: 0)
        expect(AiCall.where(status: "ok")).to be_empty
      end
    end

    context "when the libvips PNG decoder ignores chunk checksums (libspng, as in Ubuntu's libvips 8.15)" do
      before do
        decoded = double("Vips::Image", width: 64, height: 48, avg: 127.0)
        allow(Vips::Image).to receive(:new_from_buffer).and_return(decoded)
      end

      it "still rejects a PNG with corrupt data, from its CRC" do
        stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(corrupt(noisy_png)) ]))
        expect { generate }.to raise_error(Ai::InvalidResponseError, "Gemini returned a PNG with corrupt data")
        expect(AiCall.sole).to have_attributes(status: "error", error_class: "Ai::InvalidResponseError")
      end

      it "accepts an intact PNG" do
        stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(noisy_png) ]))
        expect(generate).to have_attributes(bytes: noisy_png, mime_type: "image/png")
      end
    end

    it "rejects an image over the pixel bound" do
      stub_const("Ai::Client::Vertex::MAX_GENERATED_IMAGE_PIXELS", 10) # the 8x8 test image has 64 pixels
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      expect { generate }.to raise_error(Ai::InvalidResponseError, /larger than 10 pixels/)
    end

    it "returns the image at its original size (normalizing is the job's work)" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(noisy_png) ]))
      decoded = Vips::Image.new_from_buffer(generate.bytes, "")
      expect([ decoded.width, decoded.height ]).to eq([ 64, 48 ])
    end
  end

  describe "HTTP errors (shared mapping)" do
    {
      [ 400, "INVALID_ARGUMENT" ] => Ai::InvalidRequestError, [ 403, "PERMISSION_DENIED" ] => Ai::AuthenticationError,
      [ 404, "NOT_FOUND" ] => Ai::NotFoundError, [ 429, "RESOURCE_EXHAUSTED" ] => Ai::RateLimitedError,
      [ 500, "INTERNAL" ] => Ai::TransientError, [ 503, "UNAVAILABLE" ] => Ai::TransientError
    }.each do |(code, status), klass|
      it "maps #{code} to #{klass} with one request and one error row" do
        stub_request(:post, gemini).to_return(status: code, body: JSON.generate(error: { code:, status:, message: "x" }))
        expect { generate }.to raise_error(klass, "Vertex HTTP #{code} #{status}")
        expect(a_request(:post, gemini)).to have_been_made.once
        expect(AiCall.sole).to have_attributes(status: "error", error_class: klass.name, model: "gemini-2.5-flash-image",
                                               est_cost_cents: 0, images_out: 0)
      end
    end

    it "maps a timeout to TransientError without retrying" do
      stub_request(:post, gemini).to_timeout
      expect { generate }.to raise_error(Ai::TransientError)
      expect(a_request(:post, gemini)).to have_been_made.once
    end
  end

  describe "quotas, kill switch and logging" do
    let(:user) { create(:user) }

    it "logs a success as one ok row with images_out 1 and the garment_image estimate" do
      stub_request(:post, gemini).to_return(status: 200, body: reply([ image_part(png) ]))
      generate(user:)
      expect(AiCall.sole).to have_attributes(kind: "garment_image", model: "gemini-2.5-flash-image", status: "ok", user_id: user.id,
                                             images_in: 0, images_out: 1, input_chars: prompt.length, error_class: nil,
                                             est_cost_cents: Ai::CallLogger::PRICING["garment_image"])
    end

    it "honours the kill switch: no request, no row" do
      with_env("AI_IMAGE_GEN_ENABLED" => "false") { expect { generate(user:) }.to raise_error(Ai::DisabledError) }
      expect(a_request(:post, /googleapis/)).not_to have_been_made
      expect(AiCall.count).to eq(0)
    end

    it "honours the daily image limit, counting successful images only" do
      with_env("AI_DAILY_IMAGE_LIMIT" => "1") do
        stub_request(:post, gemini).to_return({ status: 503, body: "{}" }, { status: 200, body: reply([ image_part(png) ]) })
        expect { generate(user:) }.to raise_error(Ai::TransientError) # failed attempt: not counted
        generate(user:)                                              # the one allowed image
        expect { generate(user:) }.to raise_error(Ai::QuotaExceededError)
        expect(a_request(:post, gemini)).to have_been_made.twice
      end
    end

    it "honours the global budget" do
      create(:ai_call, est_cost_cents: 2000, created_at: Time.current)
      expect { generate(user:) }.to raise_error(Ai::QuotaExceededError)
      expect(a_request(:post, /googleapis/)).not_to have_been_made
    end

    it "keeps the prompt, image data and token out of errors, logs and ai_calls" do
      log = StringIO.new
      allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log))
      allow(Ai::GoogleToken).to receive(:fetch).and_return("tok-SECRET")
      echo = "tok-SECRET #{prompt} #{Base64.strict_encode64(png)}"
      stub_request(:post, gemini).to_return(status: 400, body: JSON.generate(error: { code: 400, status: "INVALID_ARGUMENT", message: echo }))
      error = (generate rescue $!)
      [ error.message, error.inspect, log.string, AiCall.sole.attributes.to_json ].each do |surface|
        [ "tok-SECRET", prompt, Base64.strict_encode64(png) ].each { expect(surface).not_to include(_1) }
      end
    end
  end
end
