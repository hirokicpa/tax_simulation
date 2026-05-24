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

ActiveRecord::Schema.define(version: 2026_05_09_120000) do

  create_table "answers", force: :cascade do |t|
    t.text "content"
    t.integer "user_id", null: false
    t.integer "question_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["user_id"], name: "index_answers_on_user_id"
  end

  create_table "boards", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "title"
  end

  create_table "similar_industries", force: :cascade do |t|
    t.integer "year", null: false
    t.string "industry_number", null: false
    t.string "major_category"
    t.string "middle_category"
    t.string "small_category"
    t.string "industry_name", null: false
    t.decimal "stock_price_a_average", precision: 12, scale: 2, null: false
    t.decimal "dividend_b", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "profit_c", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "net_asset_d", precision: 12, scale: 4, default: "0.0", null: false
    t.string "source_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["year", "industry_number"], name: "index_similar_industries_on_year_and_number", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.integer "board_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["board_id"], name: "index_questions_on_board_id"
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "first_name"
    t.string "last_name"
    t.string "occupation"
    t.string "age"
    t.string "avatar"
    t.boolean "authority_answer", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "users"
  add_foreign_key "questions", "boards"
  add_foreign_key "questions", "users"
end
