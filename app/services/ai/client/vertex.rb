# frozen_string_literal: true

module Ai
  class Client
    # Vertex AI (Gemini, Imagen) and Discovery Engine over REST.
    #
    # Errors (design doc 3.7, extended in Phase 2; see docs/handoff/phase-2.md):
    #   400 -> InvalidRequestError, or ContentBlockedError when Google's structured ErrorInfo names a safety reason
    #   401, 403 -> AuthenticationError; 404 -> NotFoundError; 429 -> RateLimitedError (a TransientError)
    #   408, 5xx, timeouts, connection failures -> TransientError; any other 4xx -> InvalidRequestError
    #   2xx that is unusable -> InvalidResponseError; ContentBlockedError only with an explicit safety indicator
    # Error messages and logs carry only validated structured values (HTTP status, Google status code), never
    # prompts, images, tokens, request bodies or response bodies. There are no HTTP-level retries: the jobs'
    # retry_on Ai::TransientError owns retries, so a POST is never repeated behind their back.
    class Vertex < Client
      # Canonical google.rpc.Code names; anything else in error.status is ignored.
      GOOGLE_STATUS_CODES = %w[
        CANCELLED UNKNOWN INVALID_ARGUMENT DEADLINE_EXCEEDED NOT_FOUND ALREADY_EXISTS PERMISSION_DENIED
        RESOURCE_EXHAUSTED FAILED_PRECONDITION ABORTED OUT_OF_RANGE UNIMPLEMENTED INTERNAL UNAVAILABLE
        DATA_LOSS UNAUTHENTICATED
      ].freeze
      ENUM_FORMAT = /\A[A-Z][A-Z0-9_]{0,63}\z/
      # A 400 is a safety block only when an ErrorInfo detail's reason (an enum, not free text) names one.
      # The exact reasons Vertex uses are not documented for every model; verify with the first real calls.
      SAFETY_REASON = /(?:\A|_)(?:SAFETY|RAI|RESPONSIBLE_AI|PROHIBITED_CONTENT|BLOCKLIST)(?:_|\z)/
      ERROR_INFO_TYPE = "type.googleapis.com/google.rpc.ErrorInfo"
      # Gemini finish reasons that mean the output was withheld by a filter.
      GEMINI_BLOCKED_FINISH_REASONS = %w[SAFETY PROHIBITED_CONTENT BLOCKLIST SPII IMAGE_SAFETY RECITATION].freeze

      def generate_json(kind:, prompt:, schema:, images: [], system: nil, user: nil,
                        temperature: 0.2, max_output_tokens: 2048)
        body = gemini_body(prompt: prompt, system: system, images: images, temperature: temperature,
                           max_output_tokens: max_output_tokens, json_schema: schema)
        post_gemini(kind: kind, model: vision_model, body: body, user: user, images_in: images.size) do |json|
          text = extract_text(json)
          parse_json_output(json, text)
        end
      end

      def generate_text(kind:, prompt:, images: [], system: nil, user: nil,
                        temperature: 0.7, max_output_tokens: 512)
        body = gemini_body(prompt: prompt, system: system, images: images, temperature: temperature,
                           max_output_tokens: max_output_tokens)
        post_gemini(kind: kind, model: text_model, body: body, user: user, images_in: images.size) do |json|
          text = extract_text(json)
          raise ContentBlockedError, "Gemini withheld the response (safety)" if text.blank? && gemini_blocked?(json)

          text
        end
      end

      def grounded_text(kind:, prompt:, facts:, system: nil, user: nil, temperature: 0.7)
        check_quotas!(kind, user, 0, 0)
        attempt(kind: kind, model: grounded_model, user: user, input_chars: prompt.length) do |started|
          url = "https://discoveryengine.googleapis.com/v1/projects/#{project_number}/locations/global:generateGroundedContent"
          payload = {
            systemInstruction: system ? { parts: [ { text: system } ] } : nil,
            contents: [ { role: "user", parts: [ { text: prompt } ] } ],
            groundingSpec: {
              groundingSources: [ {
                inlineSource: {
                  groundingFacts: facts.map do |f|
                    { factText: f[:text] || f["text"], attributes: { title: f[:title] || f["title"] } }
                  end
                }
              } ]
            },
            generationSpec: { modelId: grounded_model, temperature: temperature }
          }.compact
          json = request_json(:post, url, payload)
          latency_ms = elapsed_ms(started)
          text = json.dig("candidates", 0, "content", "parts", 0, "text").to_s
          log_call(kind: kind, model: grounded_model, status: "ok", latency_ms: latency_ms, user: user,
                   input_chars: prompt.length, output_chars: text.length)
          text
        end
      end

      def generate_image(kind:, prompt:, aspect_ratio: "1:1", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 0, 1)
        attempt(kind: kind, model: imagen_model, user: user, input_chars: prompt.length) do |started|
          url = imagen_url(imagen_model)
          payload = {
            instances: [ { prompt: prompt } ],
            parameters: {
              sampleCount: 1,
              aspectRatio: aspect_ratio,
              personGeneration: "allow_adult",
              addWatermark: true,
              outputOptions: { mimeType: "image/png" }
            }
          }
          json = request_json(:post, url, payload)
          image = decode_imagen_prediction(json)
          latency_ms = elapsed_ms(started)
          log_call(kind: kind, model: imagen_model, status: "ok", latency_ms: latency_ms, user: user,
                   input_chars: prompt.length, images_out: 1)
          image
        end
      end

      def generate_image_with_subject(kind:, prompt:, subject:, aspect_ratio: "9:16", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 1, 1)
        attempt(kind: kind, model: outfit_subject_model, user: user, input_chars: prompt.length) do |started|
          url = imagen_url(outfit_subject_model)
          b64 = Base64.strict_encode64(subject.bytes)
          payload = {
            instances: [ {
              prompt: prompt,
              referenceImages: [ {
                referenceType: "REFERENCE_TYPE_SUBJECT",
                referenceId: 1,
                referenceImage: { bytesBase64Encoded: b64 },
                subjectImageConfig: { subjectType: "SUBJECT_TYPE_PERSON", subjectDescription: "illustrated person" }
              } ]
            } ],
            parameters: { sampleCount: 1, aspectRatio: aspect_ratio, personGeneration: "allow_adult" }
          }
          json = request_json(:post, url, payload)
          image = decode_imagen_prediction(json)
          latency_ms = elapsed_ms(started)
          log_call(kind: kind, model: outfit_subject_model, status: "ok", latency_ms: latency_ms, user: user,
                   input_chars: prompt.length, images_in: 1, images_out: 1)
          image
        end
      end

      def generate_image_multimodal(kind:, prompt:, images:, user: nil)
        body = gemini_body(prompt: prompt, images: images, temperature: 0.4, max_output_tokens: 2048,
                           response_modalities: %w[TEXT IMAGE])
        post_gemini(kind: kind, model: outfit_gemini_model, body: body, user: user, images_in: images.size,
                    images_out: 1) do |json|
          part = json.dig("candidates", 0, "content", "parts")&.find { |p| p["inlineData"] }
          unless part
            raise ContentBlockedError, "Gemini withheld the image (safety)" if gemini_blocked?(json)

            raise InvalidResponseError, "No image in response"
          end

          Ai::Image.new(
            bytes: Base64.decode64(part.dig("inlineData", "data")),
            mime_type: part.dig("inlineData", "mimeType") || "image/png"
          )
        end
      end

      def rank(kind:, query:, records:, top_n: 10)
        check_quotas!(kind, nil, 0, 0)
        attempt(kind: kind, model: ranking_model, user: nil, input_chars: query.length) do |started|
          url = "https://discoveryengine.googleapis.com/v1/projects/#{project_id}/locations/global/rankingConfigs/default_ranking_config:rank"
          payload = {
            model: ranking_model,
            query: query,
            topN: top_n,
            records: records.map do |r|
              { id: r[:id].to_s, title: r[:title].to_s, content: r[:content].to_s }
            end
          }
          json = request_json(:post, url, payload)
          latency_ms = elapsed_ms(started)
          log_call(kind: kind, model: ranking_model, status: "ok", latency_ms: latency_ms,
                   input_chars: query.length, output_chars: records.size)
          Array(json["records"]).map { |r| { id: r["id"], score: r["score"].to_f } }
        end
      end

      private

      def post_gemini(kind:, model:, body:, user:, images_in: 0, images_out: 0)
        check_quotas!(kind, user, images_in, images_out)
        input_chars = JSON.generate(body).length
        attempt(kind: kind, model: model, user: user, input_chars: input_chars) do |started|
          json = request_json(:post, gemini_url(model), body)
          result = yield json
          latency_ms = elapsed_ms(started)
          out_chars = result.is_a?(String) ? result.length : JSON.generate(result).length
          log_call(kind: kind, model: model, status: "ok", latency_ms: latency_ms, user: user,
                   input_chars: input_chars, output_chars: out_chars,
                   images_in: images_in, images_out: images_out)
          result
        end
      end

      # One HTTP attempt. Success is logged inside the block; any failure from the request onwards is logged
      # here, exactly once, as a non-billable row, and re-raised as an Ai::Error.
      def attempt(kind:, model:, user:, input_chars:)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield started
      rescue Ai::Error, Faraday::Error => e
        error = e.is_a?(Faraday::Error) ? network_error(e) : e
        log_failure(error, kind: kind, model: model, user: user, input_chars: input_chars, started: started)
        raise error
      end

      def gemini_body(prompt:, system: nil, images: [], temperature: 0.2, max_output_tokens: 2048,
                      json_schema: nil, response_modalities: nil)
        parts = [ { text: prompt } ]
        images.each do |img|
          parts << { inlineData: { mimeType: img.mime_type, data: Base64.strict_encode64(img.bytes) } }
        end
        gen = {
          temperature: temperature,
          maxOutputTokens: max_output_tokens,
          thinkingConfig: { thinkingBudget: 0 }
        }
        if json_schema
          gen[:responseMimeType] = "application/json"
          gen[:responseSchema] = json_schema
        end
        gen[:responseModalities] = response_modalities if response_modalities
        {
          systemInstruction: system ? { parts: [ { text: system } ] } : nil,
          contents: [ { role: "user", parts: parts } ],
          generationConfig: gen
        }.compact
      end

      def extract_text(json)
        parts = json.dig("candidates", 0, "content", "parts") || []
        parts.filter_map { |p| p["text"] }.join
      end

      def parse_json_output(json, text)
        raise ContentBlockedError, "Gemini withheld the response (safety)" if text.blank? && gemini_blocked?(json)

        JSON.parse(text)
      rescue JSON::ParserError
        finish = enum_value(first_candidate(json)&.dig("finishReason"))
        raise InvalidResponseError, [ "Gemini output is not valid JSON", finish && "(finishReason #{finish})" ].compact.join(" ")
      end

      # promptFeedback.blockReason (the prompt was blocked) or a filtering finishReason on the candidate.
      def gemini_blocked?(json)
        block_reason = enum_value(json["promptFeedback"].is_a?(Hash) ? json["promptFeedback"]["blockReason"] : nil)
        return true if block_reason && block_reason != "BLOCK_REASON_UNSPECIFIED"

        GEMINI_BLOCKED_FINISH_REASONS.include?(enum_value(first_candidate(json)&.dig("finishReason")))
      end

      def first_candidate(json)
        candidate = json["candidates"].is_a?(Array) ? json["candidates"].first : nil
        candidate if candidate.is_a?(Hash)
      end

      def decode_imagen_prediction(json)
        if json["raiFilteredReason"].present? || json.dig("predictions", 0, "raiFilteredReason").present?
          raise ContentBlockedError, "Image blocked by safety filter"
        end

        b64 = json.dig("predictions", 0, "bytesBase64Encoded")
        raise InvalidResponseError, "Imagen returned no image and no safety reason" if b64.blank?

        Ai::Image.new(bytes: Base64.decode64(b64), mime_type: "image/png")
      end

      def request_json(method, url, payload)
        response = connection.public_send(method, url) do |req|
          req.headers["Authorization"] = "Bearer #{Ai::GoogleToken.fetch}"
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(payload)
        end
        raise http_error(response.status, parse_body(response.body)) unless response.status.between?(200, 299)

        json = parse_body(response.body)
        raise InvalidResponseError, "Vertex HTTP #{response.status} body is not a JSON object" unless json.is_a?(Hash)

        json
      end

      def parse_body(body)
        JSON.parse(body.to_s)
      rescue JSON::ParserError
        nil
      end

      # Classified from the HTTP status and Google's structured error fields only; error.message is never read.
      def http_error(status, body)
        google = body.is_a?(Hash) && body["error"].is_a?(Hash) ? body["error"] : {}
        google_status = google["status"].presence_in(GOOGLE_STATUS_CODES)
        klass =
          case status
          when 400 then safety_error_info?(google) ? ContentBlockedError : InvalidRequestError
          when 401, 403 then AuthenticationError
          when 404 then NotFoundError
          when 408 then TransientError
          when 429 then RateLimitedError
          when 500..599 then TransientError
          when 400..499 then InvalidRequestError
          else InvalidResponseError
          end
        klass.new([ "Vertex HTTP #{status}", google_status ].compact.join(" ")).tap do |error|
          error.http_status = status
          error.google_status = google_status
        end
      end

      def safety_error_info?(google)
        Array(google["details"]).any? do |detail|
          detail.is_a?(Hash) && detail["@type"] == ERROR_INFO_TYPE &&
            enum_value(detail["reason"])&.match?(SAFETY_REASON)
        end
      end

      def enum_value(value)
        value if value.is_a?(String) && value.match?(ENUM_FORMAT)
      end

      def network_error(error)
        TransientError.new("Vertex request failed (#{error.class.name})")
      end

      def log_failure(error, kind:, model:, user:, input_chars:, started:)
        latency_ms = elapsed_ms(started)
        log_call(kind: kind, model: model, status: error.is_a?(ContentBlockedError) ? "blocked" : "error",
                 latency_ms: latency_ms, user: user, input_chars: input_chars, error_class: error.class.name,
                 billable: false)
        Rails.logger.warn(
          "[Ai::Client::Vertex] call failed kind=#{kind} model=#{model} http=#{error.http_status || 'none'} " \
          "google_status=#{error.google_status || 'none'} error=#{error.class.name} latency_ms=#{latency_ms}"
        )
      end

      def connection
        @connection ||= Faraday.new do |f|
          f.adapter Faraday.default_adapter
          f.options.open_timeout = 10
          f.options.timeout = 120
        end
      end

      def log_call(**kwargs)
        Ai::CallLogger.log(**kwargs)
      end

      def elapsed_ms(started)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      end

      def location = ENV.fetch("GOOGLE_CLOUD_LOCATION", "us-central1")
      def project_id = ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project")
      def project_number = ENV.fetch("GOOGLE_CLOUD_PROJECT_NUMBER", "123456789")
      def text_model = ENV.fetch("VERTEX_TEXT_MODEL", "gemini-2.5-flash")
      def vision_model = ENV.fetch("VERTEX_VISION_MODEL", "gemini-2.5-flash")
      def grounded_model = ENV.fetch("GROUNDED_MODEL", "gemini-2.5-flash")
      def imagen_model = ENV.fetch("IMAGEN_MODEL", "imagen-4.0-fast-generate-001")
      def outfit_subject_model = ENV.fetch("OUTFIT_SUBJECT_MODEL", "imagen-3.0-capability-001")
      def outfit_gemini_model = ENV.fetch("OUTFIT_GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")
      def ranking_model = ENV.fetch("RANKING_MODEL", "semantic-ranker-default@latest")

      def gemini_url(model)
        "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:generateContent"
      end

      def imagen_url(model)
        "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:predict"
      end
    end
  end
end
