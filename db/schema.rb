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

ActiveRecord::Schema[8.0].define(version: 2026_11_09_120006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lti_consumers", force: :cascade do |t|
    t.string "name", null: false
    t.string "consumer_key", null: false
    t.string "shared_secret", null: false
    t.string "instance_guid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_key"], name: "index_lti_consumers_on_consumer_key", unique: true
  end

  create_table "lti_contexts", force: :cascade do |t|
    t.bigint "lti_consumer_id", null: false
    t.string "context_id", null: false
    t.string "title"
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lti_consumer_id", "context_id"], name: "index_lti_contexts_on_lti_consumer_id_and_context_id", unique: true
    t.index ["lti_consumer_id"], name: "index_lti_contexts_on_lti_consumer_id"
  end

  create_table "lti_users", force: :cascade do |t|
    t.bigint "lti_consumer_id", null: false
    t.string "lti1p1_user_id", null: false
    t.string "lti1p3_sub"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lti_consumer_id", "lti1p1_user_id"], name: "index_lti_users_on_lti_consumer_id_and_lti1p1_user_id", unique: true
    t.index ["lti_consumer_id", "lti1p3_sub"], name: "index_lti_users_on_lti_consumer_id_and_lti1p3_sub", unique: true, where: "(lti1p3_sub IS NOT NULL)"
    t.index ["lti_consumer_id"], name: "index_lti_users_on_lti_consumer_id"
  end

  create_table "polls", force: :cascade do |t|
    t.bigint "lti_context_id", null: false
    t.bigint "creator_id", null: false
    t.text "question", null: false
    t.jsonb "options", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_polls_on_creator_id"
    t.index ["lti_context_id", "created_at"], name: "index_polls_on_lti_context_id_and_created_at"
    t.index ["lti_context_id"], name: "index_polls_on_lti_context_id"
  end

  create_table "used_nonces", force: :cascade do |t|
    t.bigint "lti_consumer_id", null: false
    t.string "nonce", null: false
    t.bigint "oauth_timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lti_consumer_id", "nonce"], name: "index_used_nonces_on_lti_consumer_id_and_nonce", unique: true
    t.index ["lti_consumer_id"], name: "index_used_nonces_on_lti_consumer_id"
    t.index ["oauth_timestamp"], name: "index_used_nonces_on_oauth_timestamp"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "poll_id", null: false
    t.bigint "lti_user_id", null: false
    t.integer "option_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lti_user_id"], name: "index_votes_on_lti_user_id"
    t.index ["poll_id", "lti_user_id"], name: "index_votes_on_poll_id_and_lti_user_id", unique: true
    t.index ["poll_id"], name: "index_votes_on_poll_id"
  end

  add_foreign_key "lti_contexts", "lti_consumers"
  add_foreign_key "lti_users", "lti_consumers"
  add_foreign_key "polls", "lti_contexts"
  add_foreign_key "polls", "lti_users", column: "creator_id"
  add_foreign_key "used_nonces", "lti_consumers"
  add_foreign_key "votes", "lti_users"
  add_foreign_key "votes", "polls"
end
