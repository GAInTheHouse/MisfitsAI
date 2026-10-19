# frozen_string_literal: true

module Ai
  class CallLogger
    PRICING = YAML.load_file(Rails.root.join("config/ai_pricing.yml"))["default"].freeze

    def self.log(kind:, model:, status:, latency_ms:, user: nil, input_chars: 0, output_chars: 0,
                 images_in: 0, images_out: 0, error_class: nil)
      est = PRICING[kind.to_s].to_f
      AiCall.create!(
        user: user,
        kind: kind.to_s,
        model: model,
        status: status,
        latency_ms: latency_ms,
        input_chars: input_chars,
        output_chars: output_chars,
        images_in: images_in,
        images_out: images_out,
        est_cost_cents: est,
        error_class: error_class
      )
    end
  end
end
