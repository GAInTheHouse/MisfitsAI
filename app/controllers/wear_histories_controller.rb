# frozen_string_literal: true

class WearHistoriesController < ApplicationController
  before_action :authenticate_user!

  def show
    @garments = current_user.garments.with_attached_image.order(wear_count: :desc, last_worn_at: :desc, name: :asc)
    @in_laundry = @garments.select(&:in_laundry?)
    @most_worn = @garments.select { |g| g.wear_count.positive? }.first(6)
    @unworn = @garments.select { |g| g.wear_count.zero? && !g.hidden_from_recommendations }
    @recent_wears = GarmentWear.where(user: current_user).includes(:garment, :outfit_recommendation).recent_first.limit(25)
  end
end
