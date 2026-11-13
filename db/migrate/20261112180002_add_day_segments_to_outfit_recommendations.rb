# frozen_string_literal: true

# Issue #8: a day can have several outfits, one per time block. Existing rows become segment 0, so a day with
# one block behaves exactly as before. worn_at records "I wore this".
class AddDaySegmentsToOutfitRecommendations < ActiveRecord::Migration[8.0]
  def change
    change_table :outfit_recommendations, bulk: true do |t|
      t.integer :segment_index, null: false, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :segment_label
      t.text :change_reason
      t.datetime :worn_at
    end

    remove_index :outfit_recommendations, [ :week_plan_id, :date ], unique: true,
                 name: "index_outfit_recommendations_on_week_plan_id_and_date"
    add_index :outfit_recommendations, [ :week_plan_id, :date, :segment_index ], unique: true,
              name: "index_outfit_recommendations_on_plan_date_segment"
  end
end
