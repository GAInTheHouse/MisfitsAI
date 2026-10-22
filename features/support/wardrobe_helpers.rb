# frozen_string_literal: true

# Turns a row of the canonical "Given my wardrobe contains:" table (design doc 8.3) into Garment attributes.
module WardrobeHelpers
  COLUMN_ALIASES = {
    "color" => "color_primary",
    "hidden" => "hidden_from_recommendations"
  }.freeze

  def garment_attributes_from_row(row)
    attrs = row.to_h { |column, value| [ COLUMN_ALIASES.fetch(column, column), value.presence ] }
    unknown = attrs.keys - Garment.attribute_names
    raise ArgumentError, "Unknown wardrobe table column(s): #{unknown.join(', ')}" if unknown.any?

    # Blank cells mean "not set": drop them so column defaults (e.g. hidden = false) apply.
    attrs.compact
  end

  # CSS for the wardrobe card of the garment with this exact name (garments/_garment sets data-name).
  def garment_card_css(name)
    %(article.garment-card[data-name="#{css_string(name)}"])
  end

  # CSS for a search result card with this exact title (wardrobe/searches/_result sets data-title).
  def search_result_css(title)
    %(article.search-result[data-title="#{css_string(title)}"])
  end

  # Uses the search form already on screen (the wardrobe page's Search tab), or opens the search page.
  def search_for_garments(brand: nil, keywords: nil)
    visit new_wardrobe_search_path unless page.has_css?("#garment_search_form", visible: true, wait: 0)
    within("#garment_search_form") do
      fill_in "Brand", with: brand.to_s
      fill_in "Keywords", with: keywords.to_s
      click_button "Search"
    end
  end

  private

  def css_string(value)
    value.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
  end
end

World(WardrobeHelpers)
