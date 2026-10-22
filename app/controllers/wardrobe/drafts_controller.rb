# frozen_string_literal: true

module Wardrobe
  # PATCH /wardrobe/drafts/:id: toggle a draft's selection or edit its name and category (design doc 7.1).
  # The review form also sends these edits with the commit, so this is for saving one draft on its own.
  class DraftsController < ApplicationController
    def update
      draft = current_user.garment_drafts.find(params[:id])
      return head(:unprocessable_entity) unless GarmentDraft::COMMITTABLE_STATUSES.include?(draft.status)

      fields = params.fetch(:draft, {}).permit(:selected, :name, :category)
      draft.attrs = draft.attrs.merge(fields.slice(:name, :category).to_h.transform_values { _1.to_s.squish })
      draft.selected = ActiveModel::Type::Boolean.new.cast(fields[:selected]) if fields.key?(:selected)

      if draft.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(draft, partial: "wardrobe/photo_intakes/draft", locals: { draft: draft })
          end
          format.html { redirect_to wardrobe_photo_intake_path(draft.intake_batch) }
        end
      else
        head :unprocessable_entity
      end
    end
  end
end
