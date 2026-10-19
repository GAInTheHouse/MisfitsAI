class CreateAiCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_calls, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true
      t.string :kind
      t.string :model
      t.string :status
      t.integer :latency_ms
      t.integer :input_chars, default: 0
      t.integer :output_chars, default: 0
      t.integer :images_in, default: 0
      t.integer :images_out, default: 0
      t.decimal :est_cost_cents, precision: 8, scale: 3
      t.string :error_class
      t.timestamps
    end
    add_index :ai_calls, :kind
    add_index :ai_calls, [ :user_id, :created_at ]
    add_index :ai_calls, :created_at
  end
end
