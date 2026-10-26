# frozen_string_literal: true

class OutfitsController < ApplicationController
  before_action :authenticate_user!

  def index
    @outfits = current_user.outfits.order(date: :desc)
  end

  def show
    @outfit = current_user.outfits.find(params[:id])
  end
end
