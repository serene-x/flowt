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

ActiveRecord::Schema[7.1].define(version: 2026_05_07_180100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ai_summaries", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.text "summary_text", null: false
    t.datetime "generated_at", null: false
    t.string "data_fingerprint", null: false
    t.string "source", default: "claude", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_fingerprint"], name: "index_ai_summaries_on_data_fingerprint"
    t.index ["department_id"], name: "index_ai_summaries_on_department_id", unique: true
  end

  create_table "data_rows", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.integer "row_index", null: false
    t.jsonb "data", default: {}, null: false
    t.jsonb "flags", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id", "row_index"], name: "index_data_rows_on_dataset_id_and_row_index"
    t.index ["dataset_id"], name: "index_data_rows_on_dataset_id"
  end

  create_table "dataset_columns", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.integer "data_type", default: 3, null: false
    t.jsonb "stats", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id", "position"], name: "index_dataset_columns_on_dataset_id_and_position", unique: true
    t.index ["dataset_id"], name: "index_dataset_columns_on_dataset_id"
  end

  create_table "datasets", force: :cascade do |t|
    t.string "name", null: false
    t.integer "dataset_type", default: 5, null: false
    t.bigint "department_id"
    t.string "original_filename"
    t.integer "row_count", default: 0
    t.integer "skipped_count", default: 0
    t.integer "status", default: 0, null: false
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_type"], name: "index_datasets_on_dataset_type"
    t.index ["department_id"], name: "index_datasets_on_department_id"
    t.index ["status"], name: "index_datasets_on_status"
  end

  create_table "department_profiles", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.jsonb "snapshot_data", default: {}, null: false
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_department_profiles_on_department_id", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_departments_on_name", unique: true
    t.index ["slug"], name: "index_departments_on_slug", unique: true
  end

  create_table "import_jobs", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.string "status", default: "queued", null: false
    t.string "current_step"
    t.integer "progress_percent", default: 0, null: false
    t.text "error_message"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_import_jobs_on_created_at"
    t.index ["dataset_id"], name: "index_import_jobs_on_dataset_id"
    t.index ["status"], name: "index_import_jobs_on_status"
  end

  create_table "import_logs", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.jsonb "summary", default: {}, null: false
    t.jsonb "warnings", default: [], null: false
    t.jsonb "cleaning_diff", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id"], name: "index_import_logs_on_dataset_id"
  end

  add_foreign_key "ai_summaries", "departments"
  add_foreign_key "data_rows", "datasets"
  add_foreign_key "dataset_columns", "datasets"
  add_foreign_key "datasets", "departments"
  add_foreign_key "department_profiles", "departments"
  add_foreign_key "import_jobs", "datasets"
  add_foreign_key "import_logs", "datasets"
end
