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

ActiveRecord::Schema[7.2].define(version: 2024_09_03_011721) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "articles", force: :cascade do |t|
    t.string "title", default: ""
    t.string "description", default: ""
    t.string "url", default: ""
    t.bigint "study_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_articles_on_study_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cities_trial_center_facilities", id: false, force: :cascade do |t|
    t.bigint "city_id", null: false
    t.bigint "trial_center_facility_id", null: false
    t.index ["city_id", "trial_center_facility_id"], name: "idx_on_city_id_trial_center_facility_id_5b7bf1e074"
    t.index ["trial_center_facility_id", "city_id"], name: "idx_on_trial_center_facility_id_city_id_cfa5c5917a"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "firstname", default: ""
    t.string "lastname", default: ""
    t.string "address1", default: ""
    t.string "number1", default: ""
    t.string "email1", default: ""
    t.text "comments", default: ""
    t.string "title1", default: ""
    t.string "url", default: ""
    t.bigint "study_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_contacts_on_study_id"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "firstname"
    t.string "lastname"
    t.date "dob"
    t.string "contact_number"
    t.string "contact_address"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_patients_on_user_id"
  end

  create_table "results", force: :cascade do |t|
    t.bigint "study_id", null: false
    t.string "result_type", default: ""
    t.string "title", default: ""
    t.string "description", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_results_on_study_id"
  end

  create_table "sponsors", force: :cascade do |t|
    t.string "name"
    t.string "initials"
    t.string "shortname"
    t.string "sponsor_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "studies", force: :cascade do |t|
    t.bigint "sponsor_id", null: false
    t.string "study_status"
    t.string "local_unique_register", default: ""
    t.string "scientific_title", default: ""
    t.string "public_title", default: ""
    t.date "registered_at"
    t.date "approved_at"
    t.date "started_at"
    t.date "first_patient_at"
    t.date "global_ending_at"
    t.string "study_type"
    t.string "study_phase"
    t.string "inclusion_criteria", default: ""
    t.string "exclusion_criteria", default: ""
    t.integer "sample_size"
    t.string "main_intervention", default: ""
    t.string "control_group", default: ""
    t.integer "participant_starting_age"
    t.integer "participant_ending_age"
    t.string "sex", default: ""
    t.string "medical_preexistences", default: ""
    t.string "ethical_committee", default: ""
    t.date "ethical_approval_at"
    t.string "keywords", default: ""
    t.string "pathology", default: ""
    t.string "medication", default: ""
    t.boolean "reviewed", default: false
    t.integer "review_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsor_id"], name: "index_studies_on_sponsor_id"
  end

  create_table "studies_trial_center_facilities", id: false, force: :cascade do |t|
    t.bigint "trial_center_facility_id", null: false
    t.bigint "study_id", null: false
    t.index ["study_id", "trial_center_facility_id"], name: "idx_on_study_id_trial_center_facility_id_84f1d7c591"
    t.index ["trial_center_facility_id", "study_id"], name: "idx_on_trial_center_facility_id_study_id_831bbd6e89"
  end

  create_table "studies_users", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "study_id", null: false
    t.index ["study_id", "user_id"], name: "index_studies_users_on_study_id_and_user_id"
    t.index ["user_id", "study_id"], name: "index_studies_users_on_user_id_and_study_id"
  end

  create_table "trial_center_facilities", force: :cascade do |t|
    t.string "name", default: ""
    t.string "initials", default: ""
    t.string "email", default: ""
    t.string "description", default: ""
    t.string "contact_number", default: ""
    t.string "contact_address", default: ""
    t.string "url", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trial_cities", force: :cascade do |t|
    t.bigint "study_id", null: false
    t.string "name", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_trial_cities_on_study_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "firstname", default: ""
    t.string "lastname", default: ""
    t.string "user_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.date "dob"
    t.string "contact_number", default: ""
    t.string "contact_address", default: ""
    t.string "id_number", default: ""
    t.string "id_type", default: ""
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "articles", "studies"
  add_foreign_key "contacts", "studies"
  add_foreign_key "patients", "users"
  add_foreign_key "results", "studies"
  add_foreign_key "studies", "sponsors"
  add_foreign_key "trial_cities", "studies"
end
