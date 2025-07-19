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

ActiveRecord::Schema[7.2].define(version: 2025_07_19_071724) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "sake_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "sake_id", null: false
    t.integer "rating", limit: 2, default: 0, null: false
    t.float "taste_strength", null: false
    t.float "aroma_strength", null: false
    t.text "review"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sake_id"], name: "index_sake_logs_on_sake_id"
    t.index ["user_id"], name: "index_sake_logs_on_user_id"
  end

  create_table "sakes", force: :cascade do |t|
    t.string "product_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "sake_logs", "sakes"
  add_foreign_key "sake_logs", "users"
end
