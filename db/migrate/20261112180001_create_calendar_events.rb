# frozen_string_literal: true

# Issue #8: keep every calendar event of a day, not only the one that wins the day's type (design doc 6.7).
# week_events stays one row per day; these rows hang under it.
class CreateCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events, id: :uuid do |t|
      t.references :week_event, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :summary
      t.string :event_type, null: false, default: "casual"
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :all_day, null: false, default: false
      t.string :location
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :calendar_events, [ :week_event_id, :position ]
  end
end
