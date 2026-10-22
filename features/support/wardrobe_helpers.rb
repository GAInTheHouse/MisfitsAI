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
end

World(WardrobeHelpers)
