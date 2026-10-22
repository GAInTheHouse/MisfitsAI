# frozen_string_literal: true

class GarmentsController < ApplicationController
  include ComingSoon

  # Manual add defaults (design doc 6.4).
  MANUAL_DEFAULTS = { formality: "casual", seasonality: "all_season" }.freeze
  MANUAL_FIELDS = %i[name category color_primary formality seasonality brand size fit_notes].freeze

  before_action :set_garment, only: %i[edit update destroy hide retry_image]

  # GET /wardrobe
  def show
    @garment = Garment.new(MANUAL_DEFAULTS)
    load_wardrobe
  end

  def new
    @garment = Garment.new(MANUAL_DEFAULTS)
  end

  def create
    # Garment.new(user:) rather than current_user.garments.new: an unsaved (possibly invalid) record must not
    # join current_user.garments in memory, where size/none? checks would count it.
    @garment = Garment.new(manual_garment_attributes.merge(user: current_user))

    if @garment.save
      # The garment keeps image_status "placeholder" until the job attaches the image (design doc 6.4).
      Wardrobe::GenerateGarmentImageJob.perform_later(@garment.id) if params[:generate_image] == "1"
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = added_notice }
        format.html { redirect_to wardrobe_path, notice: added_notice }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("manual_garment_form", partial: "garments/form",
                                                                           locals: { garment: @garment }),
                 status: :unprocessable_entity
        end
        format.html do
          load_wardrobe
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    render_coming_soon(title: "Edit garment")
  end

  def update
    render_coming_soon(title: "Edit garment")
  end

  def destroy
    @garment.destroy!
    notice = "Removed #{@garment.name}."
    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice }
      format.html { redirect_back fallback_location: wardrobe_path, notice: notice }
    end
  end

  # PATCH /garments/:id/hide with hidden=true|false (design doc 6.4). A missing value hides.
  def hide
    Wardrobe::SetHidden.call(user: current_user, garment: @garment, hidden: params.fetch(:hidden, true))
    respond_to do |format|
      format.turbo_stream do
        # Hiding changes planning eligibility (visible garments only), so refresh the header too.
        render turbo_stream: [
          turbo_stream.replace(@garment, partial: "garments/garment", locals: { garment: @garment }),
          turbo_stream.replace("wardrobe_status", partial: "garments/status", locals: { user: current_user })
        ]
      end
      format.html { redirect_back fallback_location: wardrobe_path }
    end
  end

  # POST /garments/:id/retry_image: queue another product image after a failed attempt (design doc 4.3).
  def retry_image
    # Compare-and-set in one UPDATE, so two quick clicks (or two tabs) queue only one job.
    claimed = current_user.garments.where(id: @garment.id, image_status: "failed")
                          .update_all(image_status: "pending", updated_at: Time.current)
    Wardrobe::GenerateGarmentImageJob.perform_later(@garment.id) if claimed == 1
    @garment.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@garment, partial: "garments/garment", locals: { garment: @garment })
      end
      format.html { redirect_back fallback_location: wardrobe_path }
    end
  end

  private

  def set_garment
    @garment = current_user.garments.find(params[:id])
  end

  def load_wardrobe
    @category = params[:category].presence_in(Garment::CATEGORIES)
    @garments = current_user.garments.with_image_variants.recent
    @garments = @garments.by_category(@category) if @category
  end

  def manual_garment_attributes
    attrs = params.fetch(:garment, {}).permit(*MANUAL_FIELDS).to_h.symbolize_keys
    MANUAL_DEFAULTS.each { |field, default| attrs[field] = attrs[field].presence || default }
    attrs.merge(source: "manual", image_status: "placeholder")
  end

  def added_notice
    "Added #{@garment.name} to your wardrobe."
  end
end
