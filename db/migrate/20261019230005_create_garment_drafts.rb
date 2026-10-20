class CreateGarmentDrafts < ActiveRecord::Migration[8.0]
  def change
    create_table :garment_drafts, id: :uuid do |t|
      t.references :intake_batch, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :status
      t.jsonb :attrs, null: false
      t.boolean :selected, default: true
      t.integer :position
      t.string :error
      t.timestamps
    end
  end
end
