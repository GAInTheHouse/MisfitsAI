# frozen_string_literal: true

require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe Wardrobe::Search::AddResult do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:image_url) { "https://images.example.com/oxford.jpg" }

  def add(title: "Uniqlo Oxford Shirt White", image_url: self.image_url, source_url: "https://shop.example.com/oxford", **attributes)
    described_class.call(user: user, image_url: image_url, title: title, source_url: source_url, attributes: attributes)
  end

  it "saves a pending search garment for the user and queues the import (design doc 6.5)" do
    garment = nil
    expect { garment = add(category: "top", brand: "Uniqlo", color: "White", material: "Cotton", kind: "Oxford shirt",
                           formality: "business", seasonality: "mild", gender: "men") }
      .to have_enqueued_job(Wardrobe::ImportRemoteImageJob).with(kind_of(String), image_url)

    expect(garment).to have_attributes(
      user: user, name: "Uniqlo Oxford Shirt White", category: "top", source: "search", image_status: "pending",
      brand: "Uniqlo", color_primary: "white", material: "Cotton", sub_category: "oxford_shirt",
      formality: "business", seasonality: "mild", gender: "men", source_url: "https://shop.example.com/oxford"
    )
  end

  it "uses the manual-add defaults for formality and season" do
    expect(add(category: "top")).to have_attributes(formality: "casual", seasonality: "all_season")
  end

  it "trims the title to 80 characters, or falls back to the keywords" do
    expect(add(title: "A" * 120, category: "top").name).to eq("A" * 80)
    expect(add(title: "  ", keywords: "white oxford shirt", category: "top").name).to eq("white oxford shirt")
  end

  describe "category" do
    it "uses the chosen category" do
      expect(add(category: "outerwear").category).to eq("outerwear")
    end

    it "falls back to the category of the chosen kind" do
      expect(add(title: "Item 42", kind: "Chelsea boots").category).to eq("shoes")
    end

    it "falls back to a garment noun in the title or keywords" do
      expect(add(title: "Uniqlo Oxford Shirt White").category).to eq("top")
      expect(add(title: "Item 42", keywords: "linen trousers").category).to eq("bottom")
    end

    it "fails validation when no category can be found" do
      expect { add(title: "Mystery Item") }.to raise_error(ActiveRecord::RecordInvalid, /Category can't be blank/)
    end
  end

  it "keeps only an http(s) source page link" do
    expect(add(category: "top", source_url: "javascript:alert(1)").source_url).to be_nil
  end

  it "ignores a gender other than men or women" do
    expect(add(category: "top", gender: "any").gender).to be_nil
  end

  [ "javascript:alert(1)", "file:///etc/passwd", "ftp://images.example.com/x.jpg", "not a url", "", nil,
    "https://images.example.com/#{'a' * 2100}.jpg" ].each do |bad|
    it "refuses the image link #{bad.to_s.truncate(40).inspect} before saving or queueing anything" do
      expect { add(image_url: bad, category: "top") }
        .to raise_error(Wardrobe::Search::Error, "That image can't be used. Pick another result.")
        .and(not_change(Garment, :count))
      expect(enqueued_jobs).to be_empty
    end
  end

  it "queues the import only after a caller's transaction commits" do
    ActiveRecord::Base.transaction do
      add(category: "top")
      raise ActiveRecord::Rollback
    end
    expect(enqueued_jobs).to be_empty
  end
end
