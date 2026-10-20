# frozen_string_literal: true

class GarmentsController < ApplicationController
  include ComingSoon

  before_action :set_garment, only: %i[edit update destroy hide]

  def show
    render :show
  end

  def new
    render_coming_soon(title: "Add garment")
  end

  def create
    render_coming_soon(title: "Add garment")
  end

  def edit
    render_coming_soon(title: "Edit garment")
  end

  def update
    render_coming_soon(title: "Edit garment")
  end

  def destroy
    @garment.destroy!
    head :no_content
  end

  def hide
    @garment.update!(hidden_from_recommendations: true)
    head :no_content
  end

  def retry_image
    render_coming_soon(title: "Retry image")
  end

  private

  def set_garment
    @garment = current_user.garments.find(params[:id])
  end
end
