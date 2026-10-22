# frozen_string_literal: true

require "rails_helper"
require "vips"

RSpec.describe Garment do
  def jpeg(width, height)
    Vips::Image.black(width, height).new_from_image([ 200, 180, 160 ]).cast(:uchar).jpegsave_buffer(Q: 90)
  end

  def dimensions(bytes)
    image = Vips::Image.new_from_buffer(bytes, "")
    [ image.width, image.height ]
  end

  def attach_jpeg(garment, width, height)
    garment.image.attach(io: StringIO.new(jpeg(width, height)), filename: "photo.jpg", content_type: "image/jpeg")
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one_attached(:image) }
  end

  describe "validations" do
    subject { build(:garment) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(80) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_inclusion_of(:category).in_array(described_class::CATEGORIES) }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_inclusion_of(:source).in_array(described_class::SOURCES) }
    it { is_expected.to validate_inclusion_of(:image_status).in_array(described_class::IMAGE_STATUSES) }
    it { is_expected.to validate_inclusion_of(:formality).in_array(described_class::FORMALITIES).allow_nil }
    it { is_expected.to validate_inclusion_of(:seasonality).in_array(described_class::SEASONALITIES).allow_nil }
    it { is_expected.to validate_inclusion_of(:gender).in_array(described_class::GENDERS).allow_nil }
    it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:times_recommended).only_integer.is_greater_than_or_equal_to(0) }

    it "accepts exactly 80 characters" do
      expect(build(:garment, name: "a" * 80)).to be_valid
    end

    it "reports the length error the manual-add form shows" do
      garment = build(:garment, name: "a" * 81)
      garment.valid?
      expect(garment.errors.full_messages).to include("Name is too long (maximum is 80 characters)")
    end
  end

  describe "defaults" do
    subject(:garment) { described_class.new }

    it "matches the schema defaults" do
      expect(garment.image_status).to eq("ready")
      expect(garment.times_recommended).to eq(0)
      expect(garment.hidden_from_recommendations).to be(false)
    end
  end

  describe ".normalize_kind" do
    it "turns a search kind into a snake_case sub_category (design doc 12.3)" do
      expect(described_class.normalize_kind("Button-down shirt")).to eq("button_down_shirt")
      expect(described_class.normalize_kind("  Wide-Leg  Pants ")).to eq("wide_leg_pants")
      expect(described_class.normalize_kind("t-shirt")).to eq("t_shirt")
    end

    it "returns nil for blank input" do
      expect(described_class.normalize_kind(nil)).to be_nil
      expect(described_class.normalize_kind("  ")).to be_nil
    end
  end

  describe "normalization" do
    it "squishes the name" do
      expect(build(:garment, name: "  White   Oxford Shirt ").name).to eq("White Oxford Shirt")
    end

    it "normalizes sub_category" do
      expect(build(:garment, sub_category: "Crop Top").sub_category).to eq("crop_top")
    end

    it "downcases colors" do
      garment = build(:garment, color_primary: " Navy ", color_secondary: "WHITE")
      expect([ garment.color_primary, garment.color_secondary ]).to eq(%w[navy white])
    end

    it "stores blank optional fields as nil so they stay untagged" do
      garment = build(:garment, formality: "", seasonality: " ", gender: "", brand: "", size: "",
                                material: "", pattern: "", fit_notes: "", source_url: "", sub_category: "",
                                color_primary: "")
      %i[formality seasonality gender brand size material pattern fit_notes source_url sub_category color_primary]
        .each { |attr| expect(garment.public_send(attr)).to be_nil, "expected #{attr} to be nil" }
      expect(garment).to be_valid
    end

    it "strips surrounding whitespace from free-text fields" do
      expect(build(:garment, brand: " Uniqlo ").brand).to eq("Uniqlo")
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:shirt) { create(:garment, :top, user: user, created_at: 2.days.ago) }
    let!(:jeans) { create(:garment, :bottom, user: user, created_at: 1.day.ago) }
    let!(:hidden_dress) { create(:garment, :dress, :hidden, user: user, created_at: 3.days.ago) }

    it ".visible excludes garments hidden from recommendations" do
      expect(user.garments.visible).to contain_exactly(shirt, jeans)
    end

    it ".by_category filters by category" do
      expect(user.garments.by_category("bottom")).to contain_exactly(jeans)
    end

    it ".recent orders newest first" do
      expect(user.garments.recent).to eq([ jeans, shirt, hidden_dress ])
    end
  end

  describe "#tags" do
    it "is category, formality and seasonality without blanks (design doc 5.3)" do
      expect(build(:garment, category: "top", formality: "business", seasonality: nil).tags).to eq(%w[top business])
    end
  end

  describe "placeholder images (design doc 6.4)" do
    described_class::CATEGORIES.each do |category|
      it "has a 512x512 JPEG placeholder for #{category}" do
        path = Rails.root.join("app/assets/images/placeholders/#{category}.jpg")
        bytes = File.binread(path)
        expect(Marcel::MimeType.for(StringIO.new(bytes))).to eq("image/jpeg")
        expect(dimensions(bytes)).to eq([ 512, 512 ])
      end

      it "serves the #{category} placeholder through the asset pipeline when no image is attached" do
        garment = build(:garment, category: category)
        expect(garment.placeholder_asset).to eq("placeholders/#{category}.jpg")
        expect(garment.image_or_placeholder_url).to match(%r{\A/assets/placeholders/#{category}-\h+\.jpg\z})
      end
    end

    it "returns the attached image instead when there is one" do
      garment = create(:garment, :with_image)
      expect(garment.image_or_placeholder_url).to start_with("/rails/active_storage/blobs/")
    end
  end

  describe "image variants (design doc 5.3)" do
    let(:garment) { create(:garment) }

    it "thumb fills a 256x256 square" do
      attach_jpeg(garment, 800, 600)
      expect(dimensions(garment.image.variant(:thumb).processed.download)).to eq([ 256, 256 ])
    end

    it "card fits within 512x512 keeping the aspect ratio" do
      attach_jpeg(garment, 800, 600)
      expect(dimensions(garment.image.variant(:card).processed.download)).to eq([ 512, 384 ])
    end

    it "card does not upscale small images" do
      attach_jpeg(garment, 300, 200)
      expect(dimensions(garment.image.variant(:card).processed.download)).to eq([ 300, 200 ])
    end
  end

  describe "deleting a garment" do
    it "clears it from outfit recommendations via the database foreign key (design doc 6.4)" do
      user = create(:user)
      garment = create(:garment, :top, user: user)
      plan = WeekPlan.create!(user: user, week_start: Date.new(2026, 10, 19))
      rec = OutfitRecommendation.create!(week_plan: plan, date: plan.week_start, event_type: "casual", top: garment)

      garment.destroy!

      expect(rec.reload.top_id).to be_nil
    end
  end
end
