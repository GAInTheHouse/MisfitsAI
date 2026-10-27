# frozen_string_literal: true

module Planner
  class ExplainOutfitJob < ApplicationJob
    queue_as :default

    def perform(outfit_id)
      outfit = Outfit.find_by(id: outfit_id)
      return unless outfit

      outfit.update(explanation: "Selected based on weather and style preferences.")
    end
  end
end
