# frozen_string_literal: true

module Wardrobe
  # Commit or discard a reviewed intake batch, photo or receipt (design doc 6.6, 6.12, 7.1).
  class IntakeBatchesController < ApplicationController
    before_action :set_batch

    # POST /wardrobe/intake_batches/:id/commit with drafts[<id>][...] (photo 6.6, receipt 6.12)
    def commit
      return redirect_to(show_path, alert: "This upload is still being read.") unless @batch.ready?

      garments =
        if @batch.photo?
          Wardrobe::PhotoIntake::Commit.call(batch: @batch, edits: draft_edits)
        else
          Receipts::Commit.call(batch: @batch, edits: draft_edits, generate_images: params[:generate_images] == "1")
        end
      notice = garments.any? ? "#{garments.size} #{garments.size == 1 ? 'item' : 'items'} added" : "No new items to add."
      redirect_to wardrobe_path, notice: notice
    rescue ActiveRecord::RecordInvalid, Receipts::InvalidEditError => e
      @error = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.user_message
      @batch.reload
      render(@batch.photo? ? "wardrobe/photo_intakes/show" : "wardrobe/receipts/show", status: :unprocessable_entity)
    end

    # DELETE /wardrobe/intake_batches/:id: discard the batch, its drafts and their images.
    def destroy
      @batch.destroy!
      redirect_to(@batch.photo? ? new_wardrobe_photo_intake_path : new_wardrobe_receipt_path)
    end

    private

    def set_batch
      @batch = current_user.intake_batches.find(params[:id])
    end

    def show_path
      @batch.photo? ? wardrobe_photo_intake_path(@batch) : wardrobe_receipt_path(@batch)
    end

    # Only known fields pass; each commit service decides which of them it accepts.
    def draft_edits
      raw = params[:drafts]
      return {} unless raw.respond_to?(:to_unsafe_h)

      fields = %w[selected name category brand size color_primary price]
      raw.to_unsafe_h.to_h { |id, values| [ id.to_s, values.respond_to?(:to_h) ? values.to_h.slice(*fields) : {} ] }
    end
  end
end
