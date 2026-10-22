# frozen_string_literal: true

require "rails_helper"

# Design doc 6.12 / 8.4. [DEVIATION] The original receipt_parser.py tests are not available; these inputs are
# written from the 6.12 algorithm. Three bugs of the original are fixed (see TextParser) and pinned here.
RSpec.describe Receipts::TextParser do
  def parse(text) = described_class.call(text)
  def one(text) = parse(text).sole

  it "reads a typical receipt: items with price, size, color and the header brand; totals and order lines dropped" do
    items = parse("UNIQLO\nOrder #12345\nOxford Shirt White M $39.90\nSlim Fit Chinos Khaki 32 $49.90\n" \
                  "Subtotal $89.80\nTax $7.18\nShipping $0.00\nTotal $96.98\nVisa ending 4242\nThank you!")
    expect(items.map { _1.except("source_line") }).to eq([
      { "name" => "Oxford Shirt White", "brand" => "Uniqlo", "size" => "M", "color" => "white", "category" => "top",
        "category_found" => true, "price" => 39.9, "confidence" => 0.99, "needs_confirmation" => false },
      { "name" => "Slim Fit Chinos Khaki", "brand" => "Uniqlo", "size" => "32", "color" => "khaki", "category" => "bottom",
        "category_found" => true, "price" => 49.9, "confidence" => 0.99, "needs_confirmation" => false }
    ])
    expect(items.first["source_line"]).to eq("Oxford Shirt White M $39.90")
  end

  describe "confidence (6.12 step 6)" do
    it "adds 0.25 category, 0.2 price, 0.1 size, 0.07 color, 0.08 brand to a 0.3 base" do
      expect(one("Graphic tee")["confidence"]).to eq(0.55)                    # base + category
      expect(one("Graphic tee $120")["confidence"]).to eq(0.75)            # + price
      expect(one("Graphic tee L $120")["confidence"]).to eq(0.85)          # + size
      expect(one("Red graphic tee L $120")["confidence"]).to eq(0.92)      # + color
      expect(one("Nike red graphic tee L $120")["confidence"]).to eq(0.99) # + brand = 1.0, clamped to 0.99
    end

    it "[DEVIATION] does not read a price's digits as the size" do
      expect(one("Graphic tee $20.00").values_at("size", "confidence")).to eq([ nil, 0.75 ])
      expect(one("Graphic tee $120.00")["size"]).to be_nil
      expect(one("Graphic tee 15,00")["size"]).to be_nil
    end

    it "[DEVIATION] does not read a quantity or SKU digits as the size" do
      expect(one("2 Linen shirt SKU: AB-12 $30.00").values_at("name", "size")).to eq([ "Linen Shirt", nil ])
    end

    it "still finds real numeric and letter sizes" do
      expect(one("Running shoe 10 $90.00")["size"]).to eq("10")
      expect(one("Slim chinos 32 $49.90")["size"]).to eq("32")
      expect(one("Dress pants 38 $70.00")["size"]).to eq("38")
      expect(one("Hoodie XL $45.00")["size"]).to eq("XL")
      expect(one("Sneaker 9.5 $80.00")["size"]).to eq("9.5")
    end

    it "flags items under 0.75 for confirmation" do
      expect(one("Graphic tee")["needs_confirmation"]).to be(true)
      expect(one("Graphic tee $120")["needs_confirmation"]).to be(false)
    end

    it "[DEVIATION] keeps a priced line that names no garment, flagged and marked category_found: false" do
      item = one("Mystery Gadget 12.00")
      expect(item.values_at("category", "category_found", "confidence", "needs_confirmation")).to eq([ "top", false, 0.5, true ])
    end

    it "flags such a line even when its other fields push confidence to 0.75" do
      item = one("Nike blue mug L $20.00")
      expect(item.values_at("confidence", "category_found", "needs_confirmation")).to eq([ 0.75, false, true ])
    end
  end

  describe "fields" do
    it "reads $ prices, USD prices and bare decimal prices with a comma" do
      expect(one("Wool scarf USD 25.00")["price"]).to eq(25.0)
      expect(one("Wool scarf 25,50")["price"]).to eq(25.5)
    end

    it "upcases the size and finds W..L.. sizes" do
      expect(one("Denim jeans w32l30 $60.00")["size"]).to eq("W32L30")
    end

    it "takes the first color word, ignoring punctuation" do
      expect(one("Hoodie (navy), grey trim $45.00")["color"]).to eq("navy")
    end

    it "prefers a brand on the line over the header brand" do
      expect(parse("ZARA\nNike running shoe 10 $90.00").sole["brand"]).to eq("Nike")
    end

    it "uses the header brand from the first six lines only" do
      lines = [ "Store", "a", "b", "c", "d", "e", "GAP", "Linen shirt $30.00" ]
      expect(parse(lines.join("\n")).sole["brand"]).to be_nil
    end

    it "titleizes multi-word brands" do
      expect(one("New Balance sneaker 9 $80.00")["brand"]).to eq("New Balance")
    end

    it "cleans quantities, SKUs and labels out of the name" do
      expect(one("2 Linen Shirt SKU: AB-123 Color: blue Size: L $30.00")["name"]).to eq("Linen Shirt Blue")
    end

    it "uses the first category, in 6.12 order, whose hint is in the name" do
      expect(one("Shirt dress $70.00")["category"]).to eq("top") # "shirt" (top) comes before "dress"
      expect(one("Leather belt $25.00")["category"]).to eq("accessory")
    end
  end

  it "drops lines shorter than 4 characters and lines with non-item terms" do
    expect(parse("tee\nGift card $25.00\nPromo code SAVE10 -$5.00\nHat $15.00").map { _1["name"] }).to eq([ "Hat" ])
  end

  it "[DEVIATION] matches non-item terms as whole words, plurals included, not inside other words" do
    names = parse("Wool Cardigan Grey M $59.00\nGift Cards $25.00\nTaxes $3.00\nThanks for shopping\nTotal $90\n" \
                  "Taxi print tee $18.00\nOrders ship in 2 days").map { _1["name"] }
    expect(names).to eq([ "Wool Cardigan Grey", "Taxi Print Tee" ])
  end

  it "dedupes on name and price" do
    expect(parse("Black Hoodie L $45.00\nBlack Hoodie L $45.00\nBlack Hoodie L $40.00").size).to eq(2)
  end

  describe "fallback when no line is an item (6.12 step 8)" do
    it "takes a snippet around the first hint of each category, capped at 0.59 and flagged" do
      items = parse("Thanks for your order! Your linen pants shipped today. Separately we packed the tote bag.")
      expect(items.map { _1["category"] }).to eq(%w[bottom accessory])
      expect(items.map { _1["confidence"] }).to all(be <= 0.59)
      expect(items.map { _1["needs_confirmation"] }).to all(be(true))
    end

    it "takes up to 24 characters around the hint, so close words share one snippet (and its category)" do
      items = parse("Thanks for your order! Your linen pants and a cotton tote bag are on their way.")
      expect(items.map { _1["category"] }).to eq(%w[bottom bottom])
    end

    it "keeps the original's whole-word hint quirk: \"trouser\" does not match \"trousers\"" do
      expect(parse("Thanks for your order of linen trousers!")).to eq([])
    end

    it "[DEVIATION] reads a cardigan line as an item with its price (the original excluded it via \"card\")" do
      item = one("Wool Cardigan Grey M $59.00")
      expect(item.values_at("name", "price", "size", "needs_confirmation")).to eq([ "Wool Cardigan Grey", 59.0, "M", false ])
    end
  end

  it "returns nothing for text without items" do
    expect(parse("")).to eq([])
    expect(parse("Thank you for shopping with us!")).to eq([])
  end

  it "infers a category from a name for the vision parser" do
    expect(described_class.infer_category("Linen Trousers")).to eq("bottom")
    expect(described_class.infer_category("Mystery")).to eq("top")
  end
end
