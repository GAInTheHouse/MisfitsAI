class CreateGarments < ActiveRecord::Migration[8.0]
  def change
    create_table :garments, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.string :sub_category
      t.string :color_primary
      t.string :color_secondary
      t.string :pattern
      t.string :material
      t.string :formality
      t.string :seasonality
      t.string :gender
      t.string :brand
      t.string :size
      t.string :fit_notes
      t.integer :price_cents
      t.string :source, null: false
      t.string :source_url
      t.string :image_status, null: false, default: "ready"
      t.integer :times_recommended, null: false, default: 0
      t.boolean :hidden_from_recommendations, null: false, default: false
      t.timestamps
    end
    add_index :garments, [ :user_id, :category ]
  end
end
