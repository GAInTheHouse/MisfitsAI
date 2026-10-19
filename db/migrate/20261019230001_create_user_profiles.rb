class CreateUserProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_profiles, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :gender
      t.date :birthday
      t.string :skin_tone
      t.string :color_tone
      t.text :favorite_colors, array: true, default: []
      t.text :avoided_colors, array: true, default: []
      t.string :top_size
      t.string :bottom_size
      t.string :shoe_size
      t.string :hair_style
      t.string :hair_color
      t.string :body_type
      t.text :aesthetics, array: true, default: []
      t.text :brands, array: true, default: []
      t.text :style_color_tones, array: true, default: []
      t.string :avatar_status, null: false, default: "none"
      t.string :avatar_error
      t.timestamps
    end
  end
end
