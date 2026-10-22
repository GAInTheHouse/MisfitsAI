# frozen_string_literal: true

module Ai
  class Client
    class Fake < Client
      class << self
        attr_accessor :calls, :stubs

        def reset!
          @calls = []
          @stubs = {}
        end

        def stub(kind, value)
          @stubs ||= {}
          @stubs[kind.to_s] = value
        end
      end

      self.calls = []
      self.stubs = {}

      def generate_json(kind:, prompt:, schema:, images: [], system: nil, user: nil, **)
        check_quotas!(kind, user, images.size, 0) # same guards as Vertex#post_gemini (design doc 3.5, 3.7)
        record_call(:generate_json, kind, prompt, user, images_in: images.size)
        stub = self.class.stubs[kind.to_s]
        raise stub if stub.is_a?(Exception)

        return stub if stub.is_a?(Hash)

        path = Rails.root.join("spec/fixtures/ai/#{kind}.json")
        JSON.parse(File.read(path))
      end

      def generate_text(kind:, prompt:, images: [], system: nil, user: nil, **)
        check_quotas!(kind, user, images.size, 0) # same guards as Vertex#post_gemini (design doc 3.5, 3.7)
        record_call(:generate_text, kind, prompt, user, images_in: images.size)
        stub = self.class.stubs[kind.to_s]
        raise stub if stub.is_a?(Exception)
        return stub if stub.is_a?(String)

        "Fake #{kind}: #{prompt.truncate(80)}"
      end

      def grounded_text(kind:, prompt:, facts:, system: nil, user: nil, **)
        record_call(:grounded_text, kind, prompt, user)
        stub = self.class.stubs[kind.to_s]
        raise stub if stub.is_a?(Exception)
        return stub if stub.is_a?(String)

        fact_text = facts.map { |f| f[:text] || f["text"] }.join(" + ")
        "Fake #{kind}: #{fact_text}"
      end

      def generate_image(kind:, prompt:, aspect_ratio: "1:1", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 0, 1)
        record_call(:generate_image, kind, prompt, user, images_out: 1)
        stubbed_image(kind)
      end

      def generate_image_with_subject(kind:, prompt:, subject:, aspect_ratio: "9:16", user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, 1, 1)
        record_call(:generate_image_with_subject, kind, prompt, user, images_in: 1, images_out: 1)
        stubbed_image(kind)
      end

      def generate_image_multimodal(kind:, prompt:, images:, user: nil)
        check_disabled!(kind)
        check_quotas!(kind, user, images.size, 1)
        record_call(:generate_image_multimodal, kind, prompt, user, images_in: images.size, images_out: 1)
        stubbed_image(kind)
      end

      def rank(kind:, query:, records:, top_n: 10)
        record_call(:rank, kind, query, nil)
        records.first(top_n).map.with_index { |r, i| { id: r[:id] || r["id"], score: 1.0 - (i * 0.1) } }
      end

      private

      def record_call(method, kind, prompt, user, images_in: 0, images_out: 0)
        self.class.calls << { method: method, kind: kind.to_s, prompt: prompt, user_id: user&.id,
                              images_in: images_in, images_out: images_out }
        Ai::CallLogger.log(
          kind: kind,
          model: "fake",
          status: "ok",
          latency_ms: 1,
          user: user,
          input_chars: prompt.to_s.length,
          output_chars: 32,
          images_in: images_in,
          images_out: images_out
        )
      end

      def stubbed_image(kind)
        stub = self.class.stubs[kind.to_s]
        raise stub if stub.is_a?(Exception)
        return stub if stub.is_a?(Ai::Image)

        image_bytes_for(kind)
      end

      def image_bytes_for(kind)
        path = Rails.root.join("spec/fixtures/ai/#{kind}.png")
        Ai::Image.new(bytes: File.binread(path), mime_type: "image/png")
      end
    end
  end
end
