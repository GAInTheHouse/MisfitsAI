# frozen_string_literal: true

require "rails_helper"

# Pins the design doc 6.5 algorithm. The word lists are rebuilt (see WordLists), so cases use words whose
# role is clear from the doc.
RSpec.describe Wardrobe::Search::FilterAndRank do
  def result(title, original: nil, link: "https://shop.example.com/#{title.parameterize}", thumbnail: nil)
    { "title" => title, "link" => link, "original" => original || "https://img.example.com/#{title.parameterize}.jpg",
      "thumbnail" => thumbnail }
  end

  def titles(results) = results.map { _1["title"] }

  describe ".tokenize" do
    it "lowercases, splits on non-alphanumerics and keeps tokens of 3+ characters" do
      expect(described_class.tokenize("Levi's 501 T-Shirt, XL")).to eq(%w[levi 501 shirt])
    end
  end

  describe ".token_match?" do
    it "needs whole words for tokens of 5 characters or fewer (\"top\" is not in \"laptop\")" do
      expect(described_class.token_match?("black laptop stand", "top")).to be(false)
      expect(described_class.token_match?("black cotton top", "top")).to be(true)
      expect(described_class.token_match?("tops-and-tees", "tops")).to be(true)
    end

    it "accepts substrings for longer tokens" do
      expect(described_class.token_match?("sweatshirts on sale", "sweatshirt")).to be(true)
    end
  end

  it "filters out results without a garment noun (the \"laptop\" case)" do
    results = [ result("Black Laptop Stand"), result("Black Cotton Top") ]
    expect(titles(described_class.call(results, base_query: "black top", limit: 8))).to eq([ "Black Cotton Top" ])
  end

  it "ranks results matching more required tokens first" do
    results = [ result("Linen Shirt"), result("Uniqlo White Linen Shirt") ]
    ranked = described_class.call(results, base_query: "uniqlo linen shirt", color: "White", limit: 8)
    expect(titles(ranked)).to eq([ "Uniqlo White Linen Shirt", "Linen Shirt" ])
  end

  it "pushes results with negative words down" do
    results = [ result("Model wearing white shirt"), result("White Shirt") ]
    expect(titles(described_class.call(results, base_query: "white shirt", limit: 8)).first).to eq("White Shirt")
  end

  it "drops results scoring -8 or below while others remain" do
    junk = result("Model wearing shirt drawing sticker", link: "https://x.example.com/a")
    results = [ junk, result("White shirt") ]
    expect(titles(described_class.call(results, base_query: "white shirt", limit: 8))).to eq([ "White shirt" ])
  end

  it "falls back to every result with a garment noun when none pass the score gate" do
    junk = result("Model wearing shirt drawing sticker")
    expect(titles(described_class.call([ junk ], base_query: "white shirt", limit: 8))).to eq([ junk["title"] ])
  end

  it "falls back to every result in score order when none has a garment noun" do
    results = [ result("Desk lamp"), result("Black desk lamp") ]
    expect(titles(described_class.call(results, base_query: "black", limit: 8))).to eq([ "Black desk lamp", "Desk lamp" ])
  end

  it "keeps the original order for equal scores (stable)" do
    results = [ result("Shirt A"), result("Shirt B"), result("Shirt C") ]
    expect(titles(described_class.call(results, base_query: "shirt", limit: 8))).to eq([ "Shirt A", "Shirt B", "Shirt C" ])
  end

  it "ignores stopwords when deciding which tokens are required" do
    # "mens" and "new" are stopwords, so a result matching only "shirt" still counts as matching.
    filter = described_class.new(base_query: "new mens shirt", color: nil, material: nil, kind: nil)
    expect(filter.score("plain shirt")).to eq(3.0)
  end

  it "penalises results matching none of the required tokens" do
    filter = described_class.new(base_query: "linen shirt", color: nil, material: nil, kind: nil)
    expect(filter.score("cotton jacket")).to eq(-2.0 + 0.4) # cotton is an apparel hint
  end

  it "caps the apparel-hint bonus at 2.0" do
    filter = described_class.new(base_query: "", color: nil, material: nil, kind: nil)
    expect(filter.score("cotton wool linen denim silk cashmere leather")).to eq(2.0)
  end

  it "dedupes by image URL and applies the limit" do
    same = "https://img.example.com/same.jpg"
    results = [ result("Shirt 1", original: same), result("Shirt 2", original: same), result("Shirt 3"), result("Shirt 4") ]
    ranked = described_class.call(results, base_query: "shirt", limit: 2)
    expect(titles(ranked)).to eq([ "Shirt 1", "Shirt 3" ])
  end

  it "uses the thumbnail as the image URL when there is no original" do
    results = [ { "title" => "Shirt", "thumbnail" => "https://t.example.com/1.jpg" },
                { "title" => "Shirt again", "thumbnail" => "https://t.example.com/1.jpg" } ]
    expect(described_class.call(results, base_query: "shirt", limit: 8).size).to eq(1)
  end
end
