# frozen_string_literal: true

module GarmentsHelper
  # Category filter order on the wardrobe page (design doc 6.4).
  WARDROBE_FILTERS = %w[top bottom shoes accessory dress outerwear].freeze

  # The attached image's variant, or the category placeholder (design doc 6.4).
  # Returns a path, not a full URL: cards are also rendered for broadcasts outside any request, where a
  # full URL would carry the renderer's default host instead of the app's.
  def garment_image_source(garment, variant)
    if garment.image.attached? && garment.image.variable?
      main_app.rails_representation_path(garment.image.variant(variant))
    else
      garment.placeholder_asset
    end
  end

  def garment_category_label(category)
    category.to_s.humanize
  end

  def garment_option_label(list, key)
    Options.fetch(list).find { |option| option[:key] == key }&.dig(:label)
  end

  def garment_category_options
    Garment::CATEGORIES.map { |category| [ category, garment_category_label(category) ] }
  end

  def garment_select_options(list)
    Options.fetch(list).map { |option| [ option[:label], option[:key] ] }
  end

  # Kinds grouped by category for the search form (design doc 12.3 SEARCH_KINDS_BY_CATEGORY).
  def search_kind_options
    Options.fetch(:search_kinds_by_category).map { |category, kinds| [ garment_category_label(category), kinds ] }
  end
end
