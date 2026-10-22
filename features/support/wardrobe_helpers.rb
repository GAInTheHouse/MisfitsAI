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

  # Uses the Photo AI form if it is on screen (the wardrobe tab, loaded lazily in the browser);
  # otherwise opens the intake page (rack-test does not load lazy frames).
  def upload_photo(path)
    if page.has_css?("[role=tab]", exact_text: "Photo AI", visible: true, wait: 0)
      find("[role=tab]", exact_text: "Photo AI").click
    end
    visit new_wardrobe_photo_intake_path unless page.has_css?("#photo_intake_form", visible: true, wait: 2)
    within("#photo_intake_form") do
      attach_file "Outfit photo", path.to_s
      click_button "Analyze photo"
    end
    # In a browser the click returns before the upload finishes: wait until the batch card (or an upload
    # error) is shown, so later steps (e.g. running the jobs) see the request's effects.
    expect(page).to have_css("[id^='intake_batch_'], #photo_intake_form [role=alert]")
  end

  # CSS for the receipt review row of the item with this exact name (wardrobe/receipts/_row sets data-name).
  def receipt_row_css(name)
    %(article.receipt-row[data-name="#{css_string(name)}"])
  end

  # Fills the receipt form (in the yielded block) on the Receipt tab if it is on screen, else on the receipt
  # page, submits it, and waits for the result (rows, the reading card or an error).
  def submit_receipt
    if page.has_css?("[role=tab]", exact_text: "Receipt", visible: true, wait: 0)
      find("[role=tab]", exact_text: "Receipt").click
    end
    visit new_wardrobe_receipt_path unless page.has_css?("#receipt_intake_form", visible: true, wait: 2)
    within("#receipt_intake_form") do
      yield
      click_button "Read receipt"
    end
    expect(page).to have_css("[id^='intake_batch_'], #receipt_intake_form [role=alert]")
  end

  private

  def css_string(value)
    value.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
  end
end

World(WardrobeHelpers)
