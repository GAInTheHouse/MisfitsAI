# frozen_string_literal: true

module Avatars
  class PromptBuilder
    MAX_PROMPT_CHARS = ENV.fetch("IMAGE_GEN_MAX_PROMPT_CHARS", 10_000).to_i

    SUBJECT_LINES = {
      "female" => "Illustrated head-and-shoulders portrait of exactly one adult woman, character illustration with soft shading, plain off-white background, not a photograph.",
      "male"   => "Illustrated head-and-shoulders portrait of exactly one adult man, character illustration with soft shading, plain off-white background, not a photograph.",
      "other"  => "Illustrated head-and-shoulders portrait of exactly one adult person, inclusive non-stereotypical look, character illustration with soft shading, plain off-white background, not a photograph.",
      nil      => "Illustrated head-and-shoulders portrait of exactly one adult person matching the facial description below, character illustration with soft shading, plain off-white background, not a photograph."
    }.freeze

    GENDER_CLAUSES = {
      "female" => "Portrait subject is an adult female: keep feminine facial structure; do not render as male or masculine-presenting unless the description clearly indicates otherwise.",
      "male"   => "Portrait subject is an adult male: keep masculine facial structure, jaw, and brow; short or styled male-typical hair unless the hair description below says otherwise; do not render as female or feminine-presenting.",
      "other"  => "Portrait subject is an adult with inclusive, non-stereotypical or androgynous presentation; avoid defaulting to hyper-feminine or hyper-masculine stock character looks.",
      nil      => "Match apparent gender presentation and age from the facial description only; do not substitute a different gender presentation."
    }.freeze

    ANTI_STOCK = "A single distinctive individual with natural asymmetry; avoid generic stock clipart, corporate vector templates, beauty-app default faces, and symmetrical influencer glam."
    ANTI_STOCK_MALE_APPEND = " No red lipstick, no winged eyeliner, no glamour makeup or long feminine lashes unless clearly matching the reference description."

    def self.portrait(description:, context:)
      new(description: description, context: context).build
    end

    def initialize(description:, context:)
      @description = description
      @context = context
    end

    def build
      parts = []

      parts << SUBJECT_LINES[@context.gender]

      if @description.present?
        parts << "PRIMARY facial reference from the user's photo — the illustration MUST reflect these traits (interpret as stylised art, not a photo): #{@description}"
      end

      parts << GENDER_CLAUSES[@context.gender]

      if @context.skin_tone.present?
        parts << "User skin tone preference for the illustration: #{@context.skin_tone.to_s.gsub('_', ' ')}."
      end

      hair_part = build_hair_part
      parts << hair_part if hair_part

      if @context.body_type.present?
        parts << "Body type: #{@context.body_type} build."
      end

      if %w[warm cool neutral].include?(@context.color_tone.to_s)
        parts << "Overall colour palette: #{@context.color_tone} tones."
      end

      anti_stock = ANTI_STOCK.dup
      anti_stock += ANTI_STOCK_MALE_APPEND if @context.gender == "male"
      parts << anti_stock

      parts << "Square crop, centred composition, single face only."

      parts.compact.join(" ").truncate(MAX_PROMPT_CHARS, omission: "")
    end

    private

    def build_hair_part
      style = @context.hair_style.presence
      color = @context.hair_color.presence

      if style && color
        "User hair preference: #{color.gsub('_', ' ')} colour, #{style.gsub('_', ' ')} style — align with the photo description when both apply."
      elsif style
        "User hair style preference: #{style.gsub('_', ' ')}."
      elsif color
        "User hair colour preference: #{color.gsub('_', ' ')}."
      end
    end
  end
end
