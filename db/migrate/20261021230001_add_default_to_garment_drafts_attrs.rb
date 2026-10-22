# frozen_string_literal: true

# Design doc 5.3: garment_drafts.attrs is "jsonb, not null, default {}". Phase 1 created it without the default.
class AddDefaultToGarmentDraftsAttrs < ActiveRecord::Migration[8.0]
  def change
    change_column_default :garment_drafts, :attrs, from: nil, to: {}
  end
end
