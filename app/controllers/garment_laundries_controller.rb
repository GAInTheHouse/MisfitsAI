# frozen_string_literal: true

class GarmentLaundriesController < ApplicationController
  before_action :authenticate_user!

  def update
    @garment = current_user.garments.find(params[:id])
    if @garment.in_laundry?
      @garment.mark_washed!
      notice = "#{@garment.name} marked clean and ready to wear."
    else
      @garment.send_to_laundry!
      notice = "#{@garment.name} sent to laundry."
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@garment), partial: "garments/garment", locals: { garment: @garment })
      end
      format.html { redirect_back fallback_location: wardrobe_path, notice: notice }
    end
  end

  def wash_all
    laundry_items = current_user.garments.in_laundry
    count = laundry_items.count
    laundry_items.find_each(&:mark_washed!)
    notice = count.positive? ? "Washed #{count} #{'item'.pluralize(count)} — everything is clean!" : "Laundry basket is already empty."
    redirect_back fallback_location: wardrobe_path, notice: notice
  end
end
