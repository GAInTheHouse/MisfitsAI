#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot generator for Phase 1 scaffolding (run once from repo root).
require "fileutils"

ROOT = File.expand_path("..", __dir__)

def write(path, content)
  full = File.join(ROOT, path)
  FileUtils.mkdir_p(File.dirname(full))
  File.write(full, content)
  puts "wrote #{path}"
end

# Migrations
write "db/migrate/20261019230001_create_user_profiles.rb", <<~RUBY
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
RUBY

write "db/migrate/20261019230002_create_body_measurements.rb", <<~RUBY
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
RUBY

write "db/migrate/20261019230003_create_garments.rb", <<~RUBY
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
      add_index :garments, [:user_id, :category]
    end
  end
RUBY

write "db/migrate/20261019230004_create_intake_batches.rb", <<~RUBY
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
RUBY

write "db/migrate/20261019230005_create_garment_drafts.rb", <<~RUBY
  class CreateGarmentDrafts < ActiveRecord::Migration[8.0]
    def change
      create_table :garment_drafts, id: :uuid do |t|
        t.references :intake_batch, type: :uuid, null: false, foreign_key: true
        t.references :user, type: :uuid, null: false, foreign_key: true
        t.string :status
        t.jsonb :attrs, null: false, default: {}
        t.boolean :selected, default: true
        t.integer :position
        t.string :error
        t.timestamps
      end
    end
  end
RUBY

write "db/migrate/20261019230006_create_week_plans.rb", <<~RUBY
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
      add_index :week_plans, [:user_id, :week_start], unique: true
    end
  end
RUBY

write "db/migrate/20261019230007_create_week_events.rb", <<~RUBY
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
      add_index :week_events, [:week_plan_id, :date], unique: true
    end
  end
RUBY

write "db/migrate/20261019230008_create_outfit_recommendations.rb", <<~RUBY
  class CreateOutfitRecommendations < ActiveRecord::Migration[8.0]
    def change
      create_table :outfit_recommendations, id: :uuid do |t|
        t.references :week_plan, type: :uuid, null: false, foreign_key: true
        t.date :date
        t.string :event_type
        t.references :top, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
        t.references :bottom, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
        t.references :dress, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
        t.references :outerwear, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
        t.references :shoes, type: :uuid, foreign_key: { to_table: :garments, on_delete: :nullify }
        t.text :explanation
        t.string :explanation_status
        t.string :preview_status, default: "none"
        t.string :preview_strategy
        t.string :preview_cache_key
        t.timestamps
      end
      add_index :outfit_recommendations, [:week_plan_id, :date], unique: true
    end
  end
RUBY

write "db/migrate/20261019230009_create_ai_calls.rb", <<~RUBY
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
      add_index :ai_calls, [:user_id, :created_at]
      add_index :ai_calls, :created_at
    end
  end
RUBY

write "db/migrate/20261019230010_create_waitlist_entries.rb", <<~RUBY
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
RUBY

write "db/migrate/20261019230011_create_solid_infrastructure.rb", <<~RUBY
  class CreateSolidInfrastructure < ActiveRecord::Migration[8.0]
    def change
      instance_eval(File.read(Rails.root.join("tmp/solid_queue.rb")), __FILE__, __LINE__)
      instance_eval(File.read(Rails.root.join("tmp/solid_cable.rb")), __FILE__, __LINE__)
      instance_eval(File.read(Rails.root.join("tmp/solid_cache.rb")), __FILE__, __LINE__)
    end
  end
RUBY

puts "Done migrations."
