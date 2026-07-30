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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_000003) do
  create_table "financial_transactions", force: :cascade do |t|
    t.bigint "amount"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3
    t.string "currency_code"
    t.datetime "date"
    t.string "description"
    t.bigint "discount"
    t.string "discount_currency", limit: 3
    t.decimal "price_amount", precision: 20, scale: 4
    t.string "price_currency"
    t.bigint "tax"
    t.decimal "total_amount", precision: 20, scale: 4
    t.datetime "updated_at", null: false
  end

  create_table "minting_composite", force: :cascade do |t|
    t.integer "price_amount"
    t.string "price_currency"
  end

  create_table "minting_composite_decimal", force: :cascade do |t|
    t.decimal "price_amount"
    t.string "price_currency"
  end

  create_table "offers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.decimal "price_amount", precision: 20, scale: 4
    t.string "price_currency"
    t.string "product"
    t.datetime "updated_at", null: false
  end

  create_table "simple_offers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.decimal "discount", precision: 20, scale: 4
    t.decimal "price", precision: 20, scale: 4
    t.string "product"
    t.datetime "updated_at", null: false
  end

  create_table "test_composite", force: :cascade do |t|
    t.integer "price_cents"
    t.string "price_currency"
  end
end
