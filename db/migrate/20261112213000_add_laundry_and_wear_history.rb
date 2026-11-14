# frozen_string_literal: true

class AddLaundryAndWearHistory < ActiveRecord::Migration[8.0]
  def change
    change_table :garments, bulk: true do |t|
      t.string :laundry_status, null: false, default: "clean"
      t.integer :wears_since_wash, null: false, default: 0
      t.integer :wash_threshold
      t.integer :wear_count, null: false, default: 0
      t.datetime :last_worn_at
      t.datetime :last_washed_at
    end

    add_index :garments, [ :user_id, :laundry_status ]

    create_table :garment_wears, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :garment, type: :uuid, null: false, foreign_key: true
      t.references :outfit_recommendation, type: :uuid, null: true, foreign_key: true
      t.date :worn_on, null: false
      t.string :source, null: false, default: "outfit_confirm"
      t.timestamps
    end

    add_index :garment_wears, [ :user_id, :worn_on ]
    add_index :garment_wears, [ :garment_id, :worn_on ]
    add_index :garment_wears, [ :outfit_recommendation_id, :garment_id ],
              unique: true,
              where: "outfit_recommendation_id IS NOT NULL",
              name: "index_garment_wears_on_outfit_and_garment"
  end
end
