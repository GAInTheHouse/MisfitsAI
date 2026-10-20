class CreateOutfitRecommendations < ActiveRecord::Migration[8.0]
  def change
    create_table :outfit_recommendations, id: :uuid do |t|
      t.references :week_plan, type: :uuid, null: false, foreign_key: true
      t.date :date
      t.string :event_type
      t.references :top, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
      t.references :bottom, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
      t.references :dress, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
      t.references :outerwear, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
      t.references :shoes, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
      t.text :explanation
      t.string :explanation_status
      t.string :preview_status, default: "none"
      t.string :preview_strategy
      t.string :preview_cache_key
      t.timestamps
    end
    add_index :outfit_recommendations, [ :week_plan_id, :date ], unique: true
  end
end
