class CreateBodyMeasurements < ActiveRecord::Migration[8.0]
  def change
    create_table :body_measurements, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.decimal :height_cm, precision: 5, scale: 1
      t.decimal :weight_kg, precision: 5, scale: 1
      t.decimal :chest_cm, precision: 5, scale: 1
      t.decimal :waist_cm, precision: 5, scale: 1
      t.decimal :hips_cm, precision: 5, scale: 1
      t.decimal :inseam_cm, precision: 5, scale: 1
      t.timestamps
    end
  end
end
