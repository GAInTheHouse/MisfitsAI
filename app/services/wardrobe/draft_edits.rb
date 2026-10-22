# frozen_string_literal: true

module Wardrobe
  # Applies review edits to a batch's drafts before committing (photo intake 6.6, receipts 6.12).
  #
  #   DraftEdits.apply(batch:, edits: { draft_id => { "selected" =>, "name" =>, ... } }, fields: %w[name category])
  #
  # Only drafts of this batch that can still be committed are touched; unknown ids are ignored. "selected"
  # is always editable; other keys only when listed in fields. Values are squished; blanks become nil.
  # Call it inside the batch lock, before committing.
  module DraftEdits
    module_function

    def apply(batch:, edits:, fields:)
      edits = edits.to_h.transform_keys(&:to_s)
      batch.garment_drafts.where(id: edits.keys).find_each do |draft|
        next unless GarmentDraft::COMMITTABLE_STATUSES.include?(draft.status)

        edit = edits[draft.id].to_h.stringify_keys
        changes = edit.slice(*fields).transform_values { _1.to_s.squish.presence }
        yield(draft, changes) if block_given? # lets the caller convert values (e.g. a price)
        selected = edit.key?("selected") ? ActiveModel::Type::Boolean.new.cast(edit["selected"]) : draft.selected
        draft.update!(attrs: draft.attrs.merge(changes), selected: selected)
      end
    end
  end
end
