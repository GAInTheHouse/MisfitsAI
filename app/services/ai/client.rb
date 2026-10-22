# frozen_string_literal: true

module Ai
  # Errors live in their own files (app/services/ai/*_error.rb) so they autoload on first use.
  class Client
    def self.current
      @current = nil if Rails.env.test? # allow adapter switching in tests
      @current ||= build_adapter
    end

    def self.build_adapter
      ENV.fetch("AI_ADAPTER", "vertex") == "fake" ? Client::Fake.new : Client::Vertex.new
    end

    def generate_json(kind:, prompt:, schema:, images: [], system: nil, user: nil,
                      temperature: 0.2, max_output_tokens: 2048)
      raise NotImplementedError
    end

    def generate_text(kind:, prompt:, images: [], system: nil, user: nil,
                      temperature: 0.7, max_output_tokens: 512)
      raise NotImplementedError
    end

    def grounded_text(kind:, prompt:, facts:, system: nil, user: nil, temperature: 0.7)
      raise NotImplementedError
    end

    def generate_image(kind:, prompt:, aspect_ratio: "1:1", user: nil)
      raise NotImplementedError
    end

    def generate_image_with_subject(kind:, prompt:, subject:, aspect_ratio: "9:16", user: nil)
      raise NotImplementedError
    end

    def generate_image_multimodal(kind:, prompt:, images:, user: nil)
      raise NotImplementedError
    end

    def rank(kind:, query:, records:, top_n: 10)
      raise NotImplementedError
    end

    protected

    def with_guards(kind:, user:, images_in: 0, images_out: 0)
      check_disabled!(kind)
      check_quotas!(kind, user, images_in, images_out)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      [ result, latency_ms ]
    rescue Ai::Error => e
      raise e
    end

    def check_disabled!(kind)
      return unless Ai::Kinds::IMAGE_OUTPUT.include?(kind.to_s)
      return if ActiveModel::Type::Boolean.new.cast(ENV.fetch("AI_IMAGE_GEN_ENABLED", "true"))

      raise DisabledError, "Image generation is disabled"
    end

    def check_quotas!(kind, user, images_in, images_out)
      return unless user

      if images_out.positive? && daily_image_count(user) >= ENV.fetch("AI_DAILY_IMAGE_LIMIT", 40).to_i
        raise QuotaExceededError, "Daily image limit reached"
      end

      if images_in.positive? && Ai::Kinds::IMAGE_INPUT.include?(kind.to_s) &&
         daily_vision_count(user) >= ENV.fetch("AI_DAILY_VISION_LIMIT", 30).to_i
        raise QuotaExceededError, "Daily vision limit reached"
      end

      budget = ENV.fetch("AI_DAILY_BUDGET_CENTS", 1000).to_f
      return unless daily_spend_cents >= budget

      raise QuotaExceededError, "Daily AI budget exceeded"
    end

    def daily_image_count(user)
      AiCall.where(user: user).where("created_at >= ?", Time.current.utc.beginning_of_day)
            .where("images_out > 0").count
    end

    def daily_vision_count(user)
      AiCall.where(user: user).where("created_at >= ?", Time.current.utc.beginning_of_day)
            .where("images_in > 0").count
    end

    def daily_spend_cents
      AiCall.where("created_at >= ?", Time.current.utc.beginning_of_day).sum(:est_cost_cents).to_f
    end
  end
end
