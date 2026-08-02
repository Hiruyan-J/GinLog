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

ActiveRecord::Schema[8.1].define(version: 2026_07_27_120018) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "areas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "sakenowa_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sakenowa_id"], name: "index_areas_on_sakenowa_id", unique: true
  end

  create_table "brands", force: :cascade do |t|
    t.bigint "brewery_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "name", null: false
    t.integer "sakenowa_id"
    t.datetime "updated_at", null: false
    t.index ["brewery_id"], name: "index_brands_on_brewery_id"
    t.index ["sakenowa_id"], name: "index_brands_on_sakenowa_id", unique: true, where: "(sakenowa_id IS NOT NULL)"
  end

  create_table "breweries", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "merged_into_id"
    t.string "name", null: false
    t.integer "sakenowa_id"
    t.datetime "updated_at", null: false
    t.index ["area_id"], name: "index_breweries_on_area_id"
    t.index ["merged_into_id"], name: "index_breweries_on_merged_into_id"
    t.index ["sakenowa_id"], name: "index_breweries_on_sakenowa_id", unique: true, where: "(sakenowa_id IS NOT NULL)"
  end

  create_table "sake_logs", force: :cascade do |t|
    t.float "aroma_strength", null: false
    t.datetime "created_at", null: false
    t.integer "rating", limit: 2, null: false
    t.text "review"
    t.bigint "sake_id", null: false
    t.float "taste_strength", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["sake_id"], name: "index_sake_logs_on_sake_id"
    t.index ["user_id"], name: "index_sake_logs_on_user_id"
  end

  create_table "sakes", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.string "product_name", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "product_name"], name: "index_sakes_on_brand_id_and_product_name", unique: true
    t.index ["brand_id"], name: "index_sakes_on_brand_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "brands", "breweries"
  add_foreign_key "breweries", "areas"
  add_foreign_key "breweries", "breweries", column: "merged_into_id"
  add_foreign_key "sake_logs", "sakes"
  add_foreign_key "sake_logs", "users"
  add_foreign_key "sakes", "brands"
end
