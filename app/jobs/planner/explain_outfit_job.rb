# frozen_string_literal: true

module Planner
  class ExplainOutfitJob < ApplicationJob
    queue_as :ai_text

    def perform(recommendation_id)
      rec = OutfitRecommendation.includes(:week_plan, :top, :bottom, :dress, :outerwear, :shoes)
                                .find_by(id: recommendation_id)
      return unless rec

      user = rec.week_plan.user
      prompt = Prompts.explanation_prompt(rec)
      facts = Prompts.facts(rec)
      system = Prompts::EXPLANATION_SYSTEM

      text, used_template = generate_explanation(user:, prompt:, facts:, system:, rec:)
      status = used_template ? "failed" : "ready"

      rec.update!(explanation: text, explanation_status: status)
      broadcast_card(rec, user)
    end

    private

    def generate_explanation(user:, prompt:, facts:, system:, rec:)
      client = Ai::Client.current
      text = client.grounded_text(
        kind: :outfit_explanation, prompt:, facts:, system:, temperature: 0.7, user:
      )
      [ first_sentence(text), false ]
    rescue Ai::QuotaExceededError, Ai::DisabledError
      [ template_explanation(rec), true ]
    rescue Ai::Error
      begin
        text = client.generate_text(
          kind: :outfit_explanation,
          prompt: "#{prompt}\n#{facts.join("\n")}",
          system:,
          temperature: 0.7,
          max_output_tokens: 120,
          user:
        )
        [ first_sentence(text), false ]
      rescue Ai::Error
        [ template_explanation(rec), true ]
      end
    end

    def first_sentence(text)
      text.to_s.strip.split(/(?<=[.!?])\s+/).first.to_s.presence || text.to_s.strip
    end

    def template_explanation(rec)
      day_name = rec.date.strftime("%A")
      event = rec.event_type.tr("_", " ")
      "For your #{day_name} #{event}, we've put together the best available pieces from your wardrobe."
    end

    def broadcast_card(rec, user)
      rec.reload
      Turbo::StreamsChannel.broadcast_replace_to(
        [ user, :planner ],
        target: ActionView::RecordIdentifier.dom_id(rec),
        partial: "outfits/day_card",
        locals: { rec: }
      )
    end
  end
end
