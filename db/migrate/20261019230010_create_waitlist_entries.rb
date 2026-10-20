class CreateWaitlistEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :waitlist_entries, id: :uuid do |t|
      t.string :email, null: false
      t.string :source
      t.timestamps
    end
    add_index :waitlist_entries, :email, unique: true
  end
end
