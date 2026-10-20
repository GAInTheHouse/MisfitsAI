class CreateWeekEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :week_events, id: :uuid do |t|
      t.references :week_plan, type: :uuid, null: false, foreign_key: true
      t.date :date, null: false
      t.string :event_type, null: false, default: "none"
      t.string :original_summary
      t.string :location
      t.datetime :starts_at
      t.timestamps
    end
    add_index :week_events, [ :week_plan_id, :date ], unique: true
  end
end
