class CreateIntakeBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :intake_batches, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :kind
      t.string :status
      t.integer :progress, default: 0
      t.string :error
      t.string :parser_strategy
      t.text :extracted_text_preview
      t.timestamps
    end
  end
end
