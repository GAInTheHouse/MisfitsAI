# frozen_string_literal: true

module Receipts
  # Rule-based receipt parser, a port of receipt_parser.py as specified in design doc 6.12.
  #
  #   TextParser.call(text) # => [{ "name", "brand", "size", "color", "category", "category_found", "price",
  #                         #       "confidence", "needs_confirmation", "source_line" }, ...]
  #
  # [DEVIATION] Three bugs of the original are fixed (see docs/handoff/phase-2.md):
  # - sizes are looked for after removing prices, SKUs and the quantity, so "$39.90" no longer gives size "39";
  # - non-item terms match whole words (plurals allowed), so "Cardigan" is not excluded by "card";
  # - a priced line naming no garment is still returned, but always flagged and not pre-selected
  #   (category_found: false), so it is not added unless the user ticks it.
  class TextParser
    CATEGORY_KEYWORDS = {
      "top"       => %w[shirt t-shirt tee blouse sweater hoodie cardigan blazer polo tank top],
      "bottom"    => %w[jeans pants trouser shorts skirt leggings chinos bottom],
      "dress"     => %w[dress jumpsuit],
      "outerwear" => %w[jacket coat parka trench windbreaker outerwear],
      "shoes"     => %w[shoe sneaker loafer heel boot sandals slippers],
      "accessory" => %w[bag belt hat cap scarf watch sunglasses wallet bracelet necklace earring ring]
    }.freeze # insertion order matters: first category whose hint is a substring wins
    COLOR_WORDS = %w[black white gray grey blue navy brown green olive red pink purple beige cream tan
                     khaki orange yellow gold silver].to_set.freeze
    KNOWN_BRANDS = [ "nike", "adidas", "zara", "h&m", "hm", "uniqlo", "gap", "levis", "levi's", "j.crew",
                     "jcrew", "mango", "patagonia", "lululemon", "new balance", "vans", "calvin klein", "ralph lauren",
                     "tommy hilfiger", "banana republic", "everlane", "madewell" ].freeze
    NON_ITEM_TERMS = [ "subtotal", "total", "tax", "shipping", "discount", "promo", "order", "invoice",
                       "receipt", "payment", "card", "visa", "mastercard", "thank", "return policy" ].freeze
    # Whole words, with an optional plural ("cards", "taxes", "thanks"), not parts of words ("cardigan").
    NON_ITEM_RE = /\b(?:#{NON_ITEM_TERMS.map { Regexp.escape(_1) }.join('|')})(?:e?s)?\b/i

    PRICE_RE     = /(?:usd\s*)?\$\s*(\d{1,4}(?:[.,]\d{2})?)/i
    ALT_PRICE_RE = /\b(\d{1,4}[.,]\d{2})\b/
    SIZE_RE      = /\b(XXXS|XXS|XS|S|M|L|XL|XXL|XXXL|[0-9]{1,2}(?:\.[05])?|W[0-9]{2}L[0-9]{2})\b/i
    SKU_RE       = /\b(?:sku|item|style|id|#)[:\-\s]*[a-z0-9\-]+\b/i
    QTY_RE       = /\A(?:qty\s*)?[x*]?[0-9]+\s+/i
    LABEL_RE     = /\b(?:qty|quantity|item|color|size)\b[:\-]?/i
    NAME_JUNK_RE = /[^A-Za-z0-9\-\s'&]/
    COLOR_STRIP  = ".,:;()[]{}"

    HEADER_LINES = 6
    LOW_CONFIDENCE = 0.75
    FALLBACK_MAX_CONFIDENCE = 0.59

    def self.call(text)
      new.call(text)
    end

    # The category of a garment name: the first category with a hint in it, else "top" (6.12).
    def self.infer_category(name)
      text = name.to_s.downcase
      CATEGORY_KEYWORDS.find { |_category, hints| hints.any? { text.include?(_1) } }&.first || "top"
    end

    # Confidence formula (6.12 step 6), also used by VisionParser when the AI gives none.
    def self.confidence_for(category_found:, price:, size:, color:, brand:)
      score = 0.3
      score += 0.25 if category_found
      score += 0.2 if price
      score += 0.1 if size.present?
      score += 0.07 if color.present?
      score += 0.08 if brand.present?
      score.round(2).clamp(0.0, 0.99)
    end

    # "Titleize": upper-case the first letter of each word (6.12 step 2).
    def self.titleize(text)
      text.to_s.split.map { |word| word[0].upcase + word[1..].to_s.downcase }.join(" ")
    end

    def call(text)
      lines = text.to_s.split(/\r?\n/).map(&:squish).reject(&:blank?)
      header_brand = find_brand(lines.first(HEADER_LINES).join(" "))

      items = lines.filter_map { |line| item_line?(line) && build_item(line, header_brand) }
      items = fallback_items(lines.join("\n"), header_brand) if items.empty?
      items.uniq { |item| [ item["name"].downcase, item["price"].to_s ] }
    end

    private

    def item_line?(line)
      lowered = line.downcase
      line.length >= 4 && !line.match?(NON_ITEM_RE) &&
        (price_in(line) || CATEGORY_KEYWORDS.values.flatten.any? { lowered.include?(_1) })
    end

    def build_item(line, header_brand)
      name = clean_name(line)
      return if name.blank?

      lowered_name = name.downcase
      lowered_line = line.downcase
      category = CATEGORY_KEYWORDS.find { |_c, hints| hints.any? { lowered_name.include?(_1) } }&.first ||
                 CATEGORY_KEYWORDS.find { |_c, hints| hints.any? { lowered_line.include?(_1) } }&.first || "top"
      category_found = CATEGORY_KEYWORDS.fetch(category).any? { lowered_line.include?(_1) }

      price = price_in(line)
      size = size_in(line)
      color = line.split.map { _1.delete(COLOR_STRIP).downcase }.find { COLOR_WORDS.include?(_1) }
      brand = find_brand(lowered_line) || header_brand
      confidence = self.class.confidence_for(category_found:, price:, size:, color:, brand:)

      {
        "name" => name, "brand" => brand, "size" => size, "color" => color, "category" => category,
        "category_found" => category_found, "price" => price, "confidence" => confidence,
        "needs_confirmation" => confidence < LOW_CONFIDENCE || !category_found, "source_line" => line
      }
    end

    def clean_name(line)
      name = [ PRICE_RE, ALT_PRICE_RE, SIZE_RE, SKU_RE, QTY_RE, LABEL_RE ].reduce(line) { |text, re| text.gsub(re, " ") }
      # Trims hyphens left at the ends by the removals (e.g. "SKU: AB-12" -> "-").
      self.class.titleize(name.gsub(NAME_JUNK_RE, " ").squish.gsub(/\A[\s\-]+|[\s\-]+\z/, ""))
    end

    # The size, looked for once prices, SKUs and the leading quantity are gone, so their digits are not
    # mistaken for a size. Real numeric sizes (10, 32, 38) and letter sizes are still found.
    def size_in(line)
      rest = [ PRICE_RE, ALT_PRICE_RE, SKU_RE, QTY_RE ].reduce(line) { |text, re| text.gsub(re, " ") }
      rest[SIZE_RE, 1]&.upcase
    end

    def price_in(line)
      raw = line[PRICE_RE, 1] || line[ALT_PRICE_RE, 1]
      raw&.tr(",", ".")&.to_f&.round(2)
    end

    def find_brand(text)
      lowered = text.downcase
      brand = KNOWN_BRANDS.find { lowered.include?(_1) }
      self.class.titleize(brand) if brand
    end

    # 6.12 step 8: no item lines at all. Take a snippet around the first hint found per category.
    def fallback_items(text, header_brand)
      CATEGORY_KEYWORDS.values.filter_map do |hints|
        snippet = hints.lazy.filter_map do |hint|
          text[/([A-Za-z0-9\s\-]{0,24}\b#{Regexp.escape(hint)}\b[A-Za-z0-9\s\-]{0,24})/i, 1]
        end.first
        next unless snippet

        item = build_item(snippet.squish, header_brand)
        next unless item

        confidence = [ item["confidence"], FALLBACK_MAX_CONFIDENCE ].min
        item.merge("confidence" => confidence, "needs_confirmation" => true)
      end
    end
  end
end
