# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_21_230001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "kind"
    t.string "model"
    t.string "status"
    t.integer "latency_ms"
    t.integer "input_chars", default: 0
    t.integer "output_chars", default: 0
    t.integer "images_in", default: 0
    t.integer "images_out", default: 0
    t.decimal "est_cost_cents", precision: 8, scale: 3
    t.string "error_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_calls_on_created_at"
    t.index ["kind"], name: "index_ai_calls_on_kind"
    t.index ["user_id", "created_at"], name: "index_ai_calls_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_calls_on_user_id"
  end

  create_table "body_measurements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.decimal "height_cm", precision: 5, scale: 1
    t.decimal "weight_kg", precision: 5, scale: 1
    t.decimal "chest_cm", precision: 5, scale: 1
    t.decimal "waist_cm", precision: 5, scale: 1
    t.decimal "hips_cm", precision: 5, scale: 1
    t.decimal "inseam_cm", precision: 5, scale: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_body_measurements_on_user_id", unique: true
  end

  create_table "garment_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "intake_batch_id", null: false
    t.uuid "user_id", null: false
    t.string "status"
    t.jsonb "attrs", default: {}, null: false
    t.boolean "selected", default: true
    t.integer "position"
    t.string "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["intake_batch_id"], name: "index_garment_drafts_on_intake_batch_id"
    t.index ["user_id"], name: "index_garment_drafts_on_user_id"
  end

  create_table "garments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "sub_category"
    t.string "color_primary"
    t.string "color_secondary"
    t.string "pattern"
    t.string "material"
    t.string "formality"
    t.string "seasonality"
    t.string "gender"
    t.string "brand"
    t.string "size"
    t.string "fit_notes"
    t.integer "price_cents"
    t.string "source", null: false
    t.string "source_url"
    t.string "image_status", default: "ready", null: false
    t.integer "times_recommended", default: 0, null: false
    t.boolean "hidden_from_recommendations", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "category"], name: "index_garments_on_user_id_and_category"
    t.index ["user_id"], name: "index_garments_on_user_id"
  end

  create_table "intake_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind"
    t.string "status"
    t.integer "progress", default: 0
    t.string "error"
    t.string "parser_strategy"
    t.text "extracted_text_preview"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_intake_batches_on_user_id"
  end

  create_table "outfit_recommendations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "week_plan_id", null: false
    t.date "date"
    t.string "event_type"
    t.uuid "top_id"
    t.uuid "bottom_id"
    t.uuid "dress_id"
    t.uuid "outerwear_id"
    t.uuid "shoes_id"
    t.text "explanation"
    t.string "explanation_status"
    t.string "preview_status", default: "none"
    t.string "preview_strategy"
    t.string "preview_cache_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bottom_id"], name: "index_outfit_recommendations_on_bottom_id"
    t.index ["dress_id"], name: "index_outfit_recommendations_on_dress_id"
    t.index ["outerwear_id"], name: "index_outfit_recommendations_on_outerwear_id"
    t.index ["shoes_id"], name: "index_outfit_recommendations_on_shoes_id"
    t.index ["top_id"], name: "index_outfit_recommendations_on_top_id"
    t.index ["week_plan_id", "date"], name: "index_outfit_recommendations_on_week_plan_id_and_date", unique: true
    t.index ["week_plan_id"], name: "index_outfit_recommendations_on_week_plan_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "user_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "gender"
    t.date "birthday"
    t.string "skin_tone"
    t.string "color_tone"
    t.text "favorite_colors", default: [], array: true
    t.text "avoided_colors", default: [], array: true
    t.string "top_size"
    t.string "bottom_size"
    t.string "shoe_size"
    t.string "hair_style"
    t.string "hair_color"
    t.string "body_type"
    t.text "aesthetics", default: [], array: true
    t.text "brands", default: [], array: true
    t.text "style_color_tones", default: [], array: true
    t.string "avatar_status", default: "none", null: false
    t.string "avatar_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_profiles_on_user_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.string "provider"
    t.string "uid"
    t.text "google_access_token"
    t.text "google_refresh_token"
    t.datetime "google_token_expires_at"
    t.datetime "google_calendar_connected_at"
    t.string "time_zone", default: "America/New_York", null: false
    t.datetime "onboarding_completed_at"
    t.integer "onboarding_step", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "waitlist_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_waitlist_entries_on_email", unique: true
  end

  create_table "week_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "week_plan_id", null: false
    t.date "date", null: false
    t.string "event_type", default: "none", null: false
    t.string "original_summary"
    t.string "location"
    t.datetime "starts_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["week_plan_id", "date"], name: "index_week_events_on_week_plan_id_and_date", unique: true
    t.index ["week_plan_id"], name: "index_week_events_on_week_plan_id"
  end

  create_table "week_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.date "week_start", null: false
    t.string "source"
    t.datetime "synced_at"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "week_start"], name: "index_week_plans_on_user_id_and_week_start", unique: true
    t.index ["user_id"], name: "index_week_plans_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_calls", "users"
  add_foreign_key "body_measurements", "users"
  add_foreign_key "garment_drafts", "intake_batches"
  add_foreign_key "garment_drafts", "users"
  add_foreign_key "garments", "users"
  add_foreign_key "intake_batches", "users"
  add_foreign_key "outfit_recommendations", "garments", column: "bottom_id", on_delete: :nullify
  add_foreign_key "outfit_recommendations", "garments", column: "dress_id", on_delete: :nullify
  add_foreign_key "outfit_recommendations", "garments", column: "outerwear_id", on_delete: :nullify
  add_foreign_key "outfit_recommendations", "garments", column: "shoes_id", on_delete: :nullify
  add_foreign_key "outfit_recommendations", "garments", column: "top_id", on_delete: :nullify
  add_foreign_key "outfit_recommendations", "week_plans"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_profiles", "users"
  add_foreign_key "week_events", "week_plans"
  add_foreign_key "week_plans", "users"
end
