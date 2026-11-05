# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avatars::PromptBuilder do
  def context_for(**attrs)
    defaults = {
      gender: nil, skin_tone: nil, hair_style: nil, hair_color: nil,
      body_type: nil, color_tone: nil, favorite_colors: [], avoided_colors: [],
      top_size: nil, bottom_size: nil, shoe_size: nil, measurements: nil,
      avatar_attached?: false
    }
    Profiles::Context.new(**defaults.merge(attrs))
  end

  describe ".portrait" do
    subject(:prompt) { described_class.portrait(description: description, context: context) }

    let(:description) { nil }
    let(:context)     { context_for }

    it "includes the nil-gender subject line" do
      expect(prompt).to include("matching the facial description below")
    end

    it "ends with the composition clause" do
      expect(prompt).to end_with("Square crop, centred composition, single face only.")
    end

    context "with female gender" do
      let(:context) { context_for(gender: "female") }

      it "uses the female subject line" do
        expect(prompt).to include("adult woman")
      end

      it "includes the female gender clause" do
        expect(prompt).to include("keep feminine facial structure")
      end

      it "does not include male anti-stock appendage" do
        expect(prompt).not_to include("No red lipstick")
      end
    end

    context "with male gender" do
      let(:context) { context_for(gender: "male") }

      it "uses the male subject line" do
        expect(prompt).to include("adult man")
      end

      it "includes the male gender clause" do
        expect(prompt).to include("masculine facial structure")
      end

      it "appends the male anti-stock clause" do
        expect(prompt).to include("No red lipstick")
      end
    end

    context "with other gender" do
      let(:context) { context_for(gender: "other") }

      it "uses the inclusive subject line" do
        expect(prompt).to include("inclusive non-stereotypical look")
      end
    end

    context "with a selfie description" do
      let(:description) { "Oval face, brown eyes, short dark hair." }

      it "embeds the description" do
        expect(prompt).to include("PRIMARY facial reference")
        expect(prompt).to include(description)
      end
    end

    context "with skin tone" do
      let(:context) { context_for(skin_tone: "medium_dark") }

      it "includes the skin tone with spaces" do
        expect(prompt).to include("medium dark")
      end
    end

    context "with hair style and color" do
      let(:context) { context_for(hair_style: "long_wavy", hair_color: "dark_brown") }

      it "includes both hair attributes" do
        expect(prompt).to include("dark brown colour")
        expect(prompt).to include("long wavy style")
      end
    end

    context "with hair style only" do
      let(:context) { context_for(hair_style: "short_straight") }

      it "includes style preference only" do
        expect(prompt).to include("User hair style preference: short straight")
      end
    end

    context "with hair color only" do
      let(:context) { context_for(hair_color: "auburn") }

      it "includes color preference only" do
        expect(prompt).to include("User hair colour preference: auburn")
      end
    end

    context "with body type" do
      let(:context) { context_for(body_type: "broad") }

      it "includes body type" do
        expect(prompt).to include("Body type: broad build")
      end
    end

    context "with warm color tone" do
      let(:context) { context_for(color_tone: "warm") }

      it "includes the colour palette line" do
        expect(prompt).to include("Overall colour palette: warm tones")
      end
    end

    context "with neutral color tone" do
      let(:context) { context_for(color_tone: "neutral") }

      it "includes the colour palette line" do
        expect(prompt).to include("Overall colour palette: neutral tones")
      end
    end

    context "with an unsupported color tone" do
      let(:context) { context_for(color_tone: "bold") }

      it "omits the colour palette line" do
        expect(prompt).not_to include("Overall colour palette")
      end
    end

    context "prompt length cap" do
      let(:description) { "x" * 15_000 }

      it "truncates to IMAGE_GEN_MAX_PROMPT_CHARS" do
        max = ENV.fetch("IMAGE_GEN_MAX_PROMPT_CHARS", 10_000).to_i
        expect(prompt.length).to be <= max
      end
    end
  end
end
