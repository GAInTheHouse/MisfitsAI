# frozen_string_literal: true

class OutfitsController < ApplicationController
  include ComingSoon
  def index; render_coming_soon(title: "Outfits"); end
  def show; render_coming_soon(title: "Outfit detail"); end
end
