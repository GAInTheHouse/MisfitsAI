# frozen_string_literal: true

module Planner
  module Prompts
    EXPLANATION_SYSTEM = <<~TEXT.strip
      You are a concise, friendly personal stylist. Write exactly one sentence explaining why the selected outfit suits the occasion. The look may be a one-piece outfit (e.g. a dress or jumpsuit) or separates; describe what works. Do not start the sentence with 'I' or repeat the day or event type word-for-word.
    TEXT

    module_function

    def event_label(event_type)
      ::Options.fetch(:event_types).find { _1[:key] == event_type }&.dig(:label) ||
        event_type.to_s.tr("_", " ").capitalize
    end

    def facts(rec)
      labels = []
      labels << fact_for("Outerwear", rec.outerwear)
      labels << fact_for("Top", rec.top)
      labels << fact_for("Dress", rec.dress)
      labels << fact_for("Bottom", rec.bottom)
      labels << fact_for("Shoes", rec.shoes)

      unless rec.dress || rec.top
        labels << "Top: no suitable item found"
      end
      unless rec.dress || rec.bottom
        labels << "Bottom: no suitable item found"
      end

      labels.compact.map { |text| { text:, title: text.split(":", 2).first } }
    end

    def fact_for(label, garment)
      return nil unless garment

      parts = [
        GarmentDisplay.display_name(garment),
        garment.color_primary,
        garment.formality&.tr("_", "-"),
        garment.material
      ].compact
      "#{label}: #{parts.join(' — ')}"
    end

    def explanation_prompt(rec)
      day_name = rec.date.strftime("%A")
      event = event_label(rec.event_type)
      parts = [ "Day: #{day_name}" ]
      parts << "Time: #{rec.segment_label}" if rec.segment_label.present? # issue #8: one of several outfits
      parts << "Event: #{event}"
      prompt = "#{parts.join(' | ')}. Write the one-sentence explanation for this outfit."
      rec.change_reason.present? ? "#{prompt} It is an outfit change: #{rec.change_reason}" : prompt
    end
  end
end
