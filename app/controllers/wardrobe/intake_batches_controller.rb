# frozen_string_literal: true

module Wardrobe
  # Commit or discard a reviewed intake batch (design doc 6.6, 7.1).
  class IntakeBatchesController < ApplicationController
    before_action :set_batch

    # POST /wardrobe/intake_batches/:id/commit with drafts[<id>][selected|name|category]
    def commit
      return head(:not_found) unless @batch.photo? # receipt batches are committed from Phase 2 Step 8 on
      unless @batch.ready?
        return redirect_to(wardrobe_photo_intake_path(@batch), alert: "This photo is still being analyzed.")
      end

      garments = Wardrobe::PhotoIntake::Commit.call(batch: @batch, edits: draft_edits)
      notice = garments.any? ? "#{garments.size} #{garments.size == 1 ? 'item' : 'items'} added" : "No new items to add."
      redirect_to wardrobe_path, notice: notice
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.to_sentence
      @batch.reload
      render "wardrobe/photo_intakes/show", status: :unprocessable_entity
    end

    # DELETE /wardrobe/intake_batches/:id: discard the batch, its drafts and their images.
    def destroy
      @batch.destroy!
      redirect_to new_wardrobe_photo_intake_path
    end

    private

    def set_batch
      @batch = current_user.intake_batches.find(params[:id])
    end

    def draft_edits
      raw = params[:drafts]
      return {} unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.to_h { |id, fields| [ id.to_s, fields.to_h.slice("selected", "name", "category") ] }
    end
  end
end
