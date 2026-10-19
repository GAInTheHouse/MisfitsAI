class CreateWeekPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :week_plans, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.date :week_start, null: false
      t.string :source
      t.datetime :synced_at
      t.datetime :generated_at
      t.timestamps
    end
    add_index :week_plans, [ :user_id, :week_start ], unique: true
  end
end
