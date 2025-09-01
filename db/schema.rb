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

ActiveRecord::Schema[8.0].define(version: 2025_08_31_223000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admins", force: :cascade do |t|
    t.string "contact_number"
    t.string "contact_address"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "url"
    t.bigint "study_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_articles_on_study_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cities_trial_center_branches", id: false, force: :cascade do |t|
    t.bigint "city_id", null: false
    t.bigint "trial_center_branch_id", null: false
  end

  create_table "cities_trial_center_facilities", id: false, force: :cascade do |t|
    t.bigint "city_id", null: false
    t.bigint "trial_center_facility_id", null: false
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
    t.bigint "study_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_contacts_on_study_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "phone_prefix", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "country_priority", default: 4, null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.index ["country_priority"], name: "index_countries_on_country_priority"
  end

  create_table "criteria_profiles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "study_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id", "user_id"], name: "index_criteria_profiles_on_study_id_and_user_id"
    t.index ["study_id"], name: "index_criteria_profiles_on_study_id"
    t.index ["user_id"], name: "index_criteria_profiles_on_user_id"
  end

  create_table "criteria_variables", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "value_type", null: false
    t.decimal "reference_value_1", precision: 15, scale: 6
    t.decimal "reference_value_2", precision: 15, scale: 6
    t.string "comparison_type", null: false
    t.text "conditions"
    t.bigint "criteria_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "qualitative_scale", default: [], null: false, array: true
    t.string "qualitative_value"
    t.boolean "enabled", default: true, null: false
    t.boolean "shown", default: true, null: false
    t.string "variable_type", default: "inclusion", null: false
    t.integer "criteria_order"
    t.index ["criteria_profile_id", "name"], name: "index_criteria_variables_on_criteria_profile_id_and_name"
    t.index ["criteria_profile_id", "variable_type", "criteria_order"], name: "index_cv_on_profile_type_order"
    t.index ["criteria_profile_id"], name: "index_criteria_variables_on_criteria_profile_id"
  end

  create_table "id_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "country_code", null: false
    t.string "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_id_types_on_active"
    t.index ["country_code", "code"], name: "index_id_types_on_country_code_and_code", unique: true
    t.index ["country_code"], name: "index_id_types_on_country_code"
  end

  create_table "medications", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "medications_studies", id: false, force: :cascade do |t|
    t.bigint "study_id", null: false
    t.bigint "medication_id", null: false
    t.index ["medication_id", "study_id"], name: "index_medications_studies_on_medication_id_and_study_id"
    t.index ["study_id", "medication_id"], name: "index_medications_studies_on_study_id_and_medication_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.date "dob"
    t.string "sex"
    t.string "contact_number"
    t.string "contact_address"
    t.string "email"
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "illness_description", default: ""
    t.string "id_type", default: ""
    t.string "id_number", default: ""
    t.string "country", default: ""
  end

  create_table "results", force: :cascade do |t|
    t.bigint "study_id", null: false
    t.string "result_type"
    t.string "title"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_results_on_study_id"
  end

  create_table "sponsor_reps", force: :cascade do |t|
    t.string "contact_number"
    t.string "contact_address"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sponsor_id"
    t.index ["sponsor_id"], name: "index_sponsor_reps_on_sponsor_id"
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
    t.string "scientific_title"
    t.string "public_title"
    t.date "completed_at"
    t.date "started_at"
    t.date "first_patient_at"
    t.date "global_ending_at"
    t.string "study_phase"
    t.integer "sample_size"
    t.string "main_intervention"
    t.string "sex"
    t.boolean "reviewed"
    t.integer "review_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "short_title", default: ""
    t.string "inclusion_criteria", default: ""
    t.string "exclusion_criteria", default: ""
    t.index ["sponsor_id"], name: "index_studies_on_sponsor_id"
  end

  create_table "studies_trial_center_branches", id: false, force: :cascade do |t|
    t.bigint "study_id", null: false
    t.bigint "trial_center_branch_id", null: false
  end

  create_table "studies_trial_center_facilities", id: false, force: :cascade do |t|
    t.bigint "trial_center_facility_id", null: false
    t.bigint "study_id", null: false
  end

  create_table "studies_users", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "study_id", null: false
  end

  create_table "trial_center_branch_reps", force: :cascade do |t|
    t.string "contact_number"
    t.string "contact_address"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trial_center_branch_id"
    t.index ["trial_center_branch_id"], name: "index_trial_center_branch_reps_on_trial_center_branch_id"
  end

  create_table "trial_center_branches", force: :cascade do |t|
    t.string "name"
    t.string "initials"
    t.string "email"
    t.string "description"
    t.string "contact_number"
    t.string "contact_address"
    t.string "url"
    t.bigint "trial_center_facility_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trial_center_facility_id"], name: "index_trial_center_branches_on_trial_center_facility_id"
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
    t.bigint "study_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_trial_cities_on_study_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "illness_description", default: ""
    t.string "userable_type"
    t.bigint "userable_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["userable_type", "userable_id"], name: "index_users_on_userable_type_and_userable_id"
  end

  add_foreign_key "articles", "studies"
  add_foreign_key "contacts", "studies"
  add_foreign_key "criteria_profiles", "studies"
  add_foreign_key "criteria_profiles", "users"
  add_foreign_key "criteria_variables", "criteria_profiles"
  add_foreign_key "results", "studies"
  add_foreign_key "sponsor_reps", "sponsors"
  add_foreign_key "studies", "sponsors"
  add_foreign_key "trial_center_branch_reps", "trial_center_branches"
  add_foreign_key "trial_center_branches", "trial_center_facilities"
  add_foreign_key "trial_cities", "studies"
end
