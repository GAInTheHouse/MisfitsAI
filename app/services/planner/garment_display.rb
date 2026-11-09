# frozen_string_literal: true

module Planner
  module GarmentDisplay
    module_function

    def display_name(garment)
      return nil unless garment

      if garment.brand.present? && !garment.name.downcase.include?(garment.brand.downcase)
        "#{garment.brand} #{garment.name}"
      else
        garment.name
      end
    end
  end
end
