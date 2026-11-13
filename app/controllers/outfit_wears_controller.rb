# frozen_string_literal: true

class OutfitWearsController < ApplicationController
  before_action :authenticate_user!

  def update
    @outfit = OutfitRecommendation.joins(:week_plan).where(week_plans: { user_id: current_user.id }).find(params[:id])
    @outfit.toggle_worn!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@outfit, :timeline), partial: "today_outfits/segment", locals: { outfit: @outfit }) }
      format.html { redirect_to today_outfits_path(date: @outfit.date.iso8601) }
    end
  end
end
