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

ActiveRecord::Schema[7.2].define(version: 2024_09_01_024033) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "url"
    t.bigint "studies_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["studies_id"], name: "index_articles_on_studies_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contacts", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.string "address1"
    t.string "address2"
    t.string "number1"
    t.string "number2"
    t.string "email1"
    t.string "email2"
    t.text "comments"
    t.string "title1"
    t.string "title2"
    t.string "url"
    t.bigint "studies_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["studies_id"], name: "index_contacts_on_studies_id"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "users_id", null: false
    t.string "firstname"
    t.string "lastname"
    t.date "dob"
    t.string "contact_number"
    t.string "contact_address"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["users_id"], name: "index_patients_on_users_id"
  end

  create_table "results", force: :cascade do |t|
    t.bigint "studies_id", null: false
    t.string "result_type"
    t.string "title"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["studies_id"], name: "index_results_on_studies_id"
  end

  create_table "sponsors", force: :cascade do |t|
    t.string "name"
    t.string "intials"
    t.string "shortname"
    t.string "sponsor_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "studies", force: :cascade do |t|
    t.bigint "sponsors_id", null: false
    t.string "study_status"
    t.string "local_unique_register"
    t.string "cientific_title"
    t.string "public_title"
    t.date "registrated_at"
    t.date "approved_at"
    t.date "started_at"
    t.date "first_patient_at"
    t.date "global_ending_at"
    t.string "study_type"
    t.string "study_phase"
    t.string "inclusion_criteria"
    t.string "exclusion_criteria"
    t.integer "sample_size"
    t.string "main_intervention"
    t.string "control_group"
    t.integer "participant_starting_age"
    t.integer "participant_ending_age"
    t.string "sex"
    t.string "medical_preexistencies"
    t.string "ethical_cometee"
    t.date "ethical_approval_at"
    t.string "keywords"
    t.string "pathology"
    t.string "medication"
    t.boolean "reviewed"
    t.integer "review_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsors_id"], name: "index_studies_on_sponsors_id"
  end

  create_table "trial_center_facilities", force: :cascade do |t|
    t.string "name"
    t.string "initials"
    t.string "email"
    t.string "description"
    t.string "contact_number"
    t.string "contact_address"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trial_cities", force: :cascade do |t|
    t.bigint "studies_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["studies_id"], name: "index_trial_cities_on_studies_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.string "user_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.date "dob"
    t.string "contact_number"
    t.string "contact_address"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "articles", "studies", column: "studies_id"
  add_foreign_key "contacts", "studies", column: "studies_id"
  add_foreign_key "patients", "users", column: "users_id"
  add_foreign_key "results", "studies", column: "studies_id"
  add_foreign_key "studies", "sponsors", column: "sponsors_id"
  add_foreign_key "trial_cities", "studies", column: "studies_id"
end
