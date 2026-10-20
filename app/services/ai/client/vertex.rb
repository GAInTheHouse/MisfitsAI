# frozen_string_literal: true

module Ai
  class Client
    class Vertex < Client
      def generate_json(kind:, prompt:, schema:, images: [], system: nil, user: nil,
                        temperature: 0.2, max_output_tokens: 2048)
        body = gemini_body(prompt: prompt, system: system, images: images, temperature: temperature,
                           max_output_tokens: max_output_tokens, json_schema: schema)
        post_gemini(kind: kind, model: vision_model, body: body, user: user, images_in: images.size) do |json|
          text = extract_text(json)
          JSON.parse(text)
        end
      end

      def generate_text(kind:, prompt:, images: [], system: nil, user: nil,
                        temperature: 0.7, max_output_tokens: 512)
        body = gemini_body(prompt: prompt, system: system, images: images, temperature: temperature,
                           max_output_tokens: max_output_tokens)
        post_gemini(kind: kind, model: text_model, body: body, user: user, images_in: images.size) do |json|
          extract_text(json)
        end
      end

      def grounded_text(kind:, prompt:, facts:, system: nil, user: nil, temperature: 0.7)
        check_quotas!(kind, user, 0, 0)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      rescue Faraday::Error => e
        handle_http_error(e, kind: kind, model: grounded_model, user: user, started: started)
      end

      def generate_image(kind:, prompt:, aspect_ratio: "1:1", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 0, 1)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      rescue Faraday::Error => e
        handle_http_error(e, kind: kind, model: imagen_model, user: user, started: started)
      end

      def generate_image_with_subject(kind:, prompt:, subject:, aspect_ratio: "9:16", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 1, 1)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      rescue Faraday::Error => e
        handle_http_error(e, kind: kind, model: outfit_subject_model, user: user, started: started)
      end

      def generate_image_multimodal(kind:, prompt:, images:, user: nil)
        body = gemini_body(prompt: prompt, images: images, temperature: 0.4, max_output_tokens: 2048,
                           response_modalities: %w[TEXT IMAGE])
        post_gemini(kind: kind, model: outfit_gemini_model, body: body, user: user, images_in: images.size,
                    images_out: 1) do |json|
          part = json.dig("candidates", 0, "content", "parts")&.find { |p| p["inlineData"] }
          raise ContentBlockedError, "No image in response" unless part

          Ai::Image.new(
            bytes: Base64.decode64(part.dig("inlineData", "data")),
            mime_type: part.dig("inlineData", "mimeType") || "image/png"
          )
        end
      end

      def rank(kind:, query:, records:, top_n: 10)
        check_quotas!(kind, nil, 0, 0)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      rescue Faraday::Error => e
        handle_http_error(e, kind: kind, model: ranking_model, user: nil, started: started)
      end

      private

      def post_gemini(kind:, model:, body:, user:, images_in: 0, images_out: 0)
        check_quotas!(kind, user, images_in, images_out)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        json = request_json(:post, gemini_url(model), body)
        result = yield json
        latency_ms = elapsed_ms(started)
        out_chars = result.is_a?(String) ? result.length : JSON.generate(result).length
        log_call(kind: kind, model: model, status: "ok", latency_ms: latency_ms, user: user,
                 input_chars: JSON.generate(body).length, output_chars: out_chars,
                 images_in: images_in, images_out: images_out)
        result
      rescue Faraday::Error => e
        handle_http_error(e, kind: kind, model: model, user: user, started: started)
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

      def decode_imagen_prediction(json)
        if json["raiFilteredReason"].present? || json.dig("predictions", 0, "raiFilteredReason").present?
          raise ContentBlockedError, "Image blocked by safety filter"
        end

        b64 = json.dig("predictions", 0, "bytesBase64Encoded")
        raise ContentBlockedError, "Empty Imagen response" if b64.blank?

        Ai::Image.new(bytes: Base64.decode64(b64), mime_type: "image/png")
      end

      def request_json(method, url, payload)
        response = connection.public_send(method, url) do |req|
          req.headers["Authorization"] = "Bearer #{Ai::GoogleToken.fetch}"
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(payload)
        end
        raise TransientError, "HTTP #{response.status}" if response.status >= 500
        raise ContentBlockedError, "HTTP #{response.status}" if response.status == 400
        raise TransientError, "HTTP 429" if response.status == 429

        JSON.parse(response.body)
      end

      def connection
        @connection ||= Faraday.new do |f|
          f.request :retry, max: 2, interval: 0.5, retry_statuses: [ 429, 500, 502, 503, 504 ]
          f.adapter Faraday.default_adapter
          f.options.timeout = 120
        end
      end

      def handle_http_error(error, kind:, model:, user:, started:)
        status = error.response&.dig(:status) if error.respond_to?(:response)
        latency_ms = started ? elapsed_ms(started) : 0
        mapped = map_error(status, error)
        log_call(kind: kind, model: model, status: mapped[:status], latency_ms: latency_ms, user: user,
                 error_class: mapped[:klass].name)
        raise mapped[:klass], mapped[:message]
      end

      def map_error(status, error)
        case status
        when 429 then { klass: TransientError, message: "Rate limited", status: "error" }
        when 400 then { klass: ContentBlockedError, message: error.message, status: "blocked" }
        else { klass: TransientError, message: error.message, status: "error" }
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
