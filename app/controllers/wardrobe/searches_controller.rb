# frozen_string_literal: true

module Wardrobe
  # Describe item > Search (design doc 6.5): search Google Images through SerpAPI, then add a result.
  class SearchesController < ApplicationController
    SEARCH_FIELDS = %i[brand keywords category color material kind formality seasonality gender].freeze

    rescue_from Wardrobe::Search::Error, with: :render_search_error

    # GET /wardrobe/searches/new: the search form on its own page (the wardrobe page embeds the same form).
    def new
      @search = {}
    end

    # POST /wardrobe/searches: results render into the garment_search_results frame.
    def create
      @search = search_params
      @results = Wardrobe::Search::ImageSearch.call(
        query: [ @search[:brand], @search[:keywords] ].compact_blank.join(" "),
        color: @search[:color], material: @search[:material], kind: @search[:kind], gender: @search[:gender]
      )
    end

    # POST /wardrobe/searches/select: add one result to the signed-in user's wardrobe.
    def select
      @garment = Wardrobe::Search::AddResult.call(
        user: current_user, image_url: params[:image_url], title: params[:title],
        source_url: params[:source_url], attributes: search_params
      )
      notice = "Added #{@garment.name} to your wardrobe."
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          render "garments/create"
        end
        format.html { redirect_to wardrobe_path, notice: notice }
      end
    rescue ActiveRecord::RecordInvalid => e
      add_failed(e.record.errors.full_messages.to_sentence)
    end

    private

    def search_params
      params.fetch(:search, {}).permit(*SEARCH_FIELDS).to_h.symbolize_keys
    end

    def render_search_error(error)
      return add_failed(error.user_message, status: error.status) if action_name == "select"

      @search = search_params
      @error = error.user_message
      render :create, status: error.status
    end

    def add_failed(message, status: :unprocessable_entity)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash"), status: status
        end
        format.html { redirect_back fallback_location: wardrobe_path, alert: message }
      end
    end
  end
end
