# frozen_string_literal: true

module Avatars
  module Prompts
    SELFIE = <<~PROMPT.strip
      You are helping build an illustrated avatar from a selfie. Study the face and head closely.

      Write a detailed, factual description in plain prose. Aim for roughly 150–400 words. Cover everything clearly visible:
      • Face shape, overall proportions, forehead height, cheek volume.
      • Eyebrows: thickness, arch, distance from eyes.
      • Eyes: shape, size, spacing, eyelid shape, visible iris colour if discernible, under-eye area.
      • Nose: bridge width, length, tip shape, nostril visibility.
      • Mouth and lips: width, upper/lower lip fullness, resting expression.
      • Jaw, chin, and neck (if visible): angles, width, chin shape.
      • Ears: only if visible — size, angle, prominence.
      • Skin: tone and undertone hints, texture or sheen (neutral, observational wording).
      • Facial hair: clean-shaven, stubble, beard, or mustache — coverage, shape, density.
      • Hair: hairline, density, length, how it falls, colour (including gray if visible).
      • Face-framing accessories: glasses, hat brim, etc., if present.
      • Approximate apparent age band (e.g. late twenties, forties) — structural only.

      Rules: Use neutral structural language. Do not name the person or guess their identity, job, or ethnicity labels. Do not describe clothing below the collar or the background. Do not refuse; describe only what you can see.
    PROMPT

    def self.outfit_subject(outfit_desc:)
      "Full body fashion illustration of person [1] wearing #{outfit_desc}. Show the complete outfit from head to toe, person standing upright facing forward. All clothing items clearly visible. Character illustration style, plain off-white background."
    end

    def self.outfit_gemini(outfit_desc:, n_garment_images:)
      "You are an AI fashion illustrator. The FIRST image is an illustrated avatar portrait — study this person's face, hair style, hair colour, skin tone, and facial features carefully. The next #{n_garment_images} image(s) are clothing items: #{outfit_desc}. Generate a single full-body illustrated image of the SAME character from the first image wearing ALL of the clothing items shown. Preserve the character's face, hair and skin tone exactly as in the portrait. Show every garment item clearly. Full body, head to toe, forward-facing pose. Same illustration style as the portrait. Plain off-white background."
    end
  end
end
