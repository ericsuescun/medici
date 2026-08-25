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

ActiveRecord::Schema[8.0].define(version: 2026_08_24_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
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

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "campaign_documents", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "title"
    t.string "document_type", default: "file", null: false
    t.string "external_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_campaign_documents_on_campaign_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "study_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "call_to_action"
    t.string "status", default: "draft", null: false
    t.boolean "target_instagram", default: false, null: false
    t.boolean "target_facebook", default: false, null: false
    t.boolean "target_twitter", default: false, null: false
    t.text "instagram_user_id"
    t.text "instagram_access_token"
    t.text "facebook_page_id"
    t.text "facebook_page_access_token"
    t.text "twitter_api_key"
    t.text "twitter_api_secret"
    t.text "twitter_access_token"
    t.text "twitter_access_token_secret"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_id"], name: "index_campaigns_on_study_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "categories_studies", id: false, force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "study_id", null: false
    t.index ["category_id", "study_id"], name: "index_categories_studies_on_category_id_and_study_id", unique: true
    t.index ["study_id"], name: "index_categories_studies_on_study_id"
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

  create_table "complementary_informations", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_complementary_informations_on_patient_id", unique: true
  end

  create_table "consents", force: :cascade do |t|
    t.string "document_type", null: false
    t.string "document_version", null: false
    t.string "purpose", null: false
    t.datetime "granted_at", null: false
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "patient_id", null: false
    t.index ["patient_id"], name: "index_consents_on_patient_id"
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
    t.index ["study_id"], name: "index_criteria_profiles_on_study_id_unique", unique: true, where: "(study_id IS NOT NULL)"
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
    t.string "criteria_category", default: "primary", null: false
    t.text "patient_prompt"
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

  create_table "local_parameters", force: :cascade do |t|
    t.bigint "country_id", null: false
    t.string "name", null: false
    t.string "value", null: false
    t.string "display_name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id", "name"], name: "index_local_parameters_on_country_id_and_name", unique: true
    t.index ["country_id"], name: "index_local_parameters_on_country_id"
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

  create_table "patient_declarations", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "criteria_variable_id"
    t.bigint "recorded_by_id"
    t.text "prompt", null: false
    t.string "answer"
    t.string "value_type", null: false
    t.text "qualitative_scale", default: [], null: false, array: true
    t.boolean "declined", default: false, null: false
    t.string "capture_mode", default: "public_form", null: false
    t.datetime "declared_at", null: false
    t.datetime "superseded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["criteria_variable_id"], name: "index_patient_declarations_on_criteria_variable_id"
    t.index ["patient_id", "criteria_variable_id"], name: "index_live_declarations_on_patient_and_variable", unique: true, where: "(superseded_at IS NULL)"
    t.index ["patient_id"], name: "index_patient_declarations_on_patient_id"
    t.index ["recorded_by_id"], name: "index_patient_declarations_on_recorded_by_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.string "dob"
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
    t.string "state", default: "interested", null: false
    t.string "participant_code"
    t.bigint "study_id"
    t.boolean "submitted_by_proxy", default: false, null: false
    t.boolean "adult_confirmed", default: false, null: false
    t.string "reported_city"
    t.index ["participant_code"], name: "index_patients_on_participant_code", unique: true
    t.index ["state"], name: "index_patients_on_state"
    t.index ["study_id"], name: "index_patients_on_study_id"
  end

  create_table "platform_staffs", force: :cascade do |t|
    t.string "contact_number"
    t.string "contact_address"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.string "resource", null: false
    t.boolean "can_show", default: false, null: false
    t.boolean "can_edit", default: false, null: false
    t.boolean "can_delete", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "resource"], name: "index_role_permissions_on_role_id_and_resource", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "display_name", default: "", null: false
    t.string "description", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
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
    t.boolean "international", default: false, null: false
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
    t.string "inclusion_criteria"
    t.string "exclusion_criteria"
    t.integer "sample_size"
    t.string "main_intervention"
    t.string "sex"
    t.boolean "reviewed"
    t.integer "review_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "short_title", default: ""
    t.string "study_type"
    t.boolean "local_health_authority_approved", default: false, null: false
    t.boolean "committee_approved", default: false, null: false
    t.boolean "patient_self_report_enabled", default: false, null: false
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
    t.bigint "role_id"
    t.boolean "active", default: false, null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["userable_type", "userable_id"], name: "index_users_on_userable_type_and_userable_id"
  end

  create_table "variable_values", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "value_type", null: false
    t.decimal "reference_value_1", precision: 15, scale: 6
    t.decimal "reference_value_2", precision: 15, scale: 6
    t.string "comparison_type", null: false
    t.text "conditions"
    t.text "qualitative_scale", default: [], null: false, array: true
    t.string "qualitative_value"
    t.string "variable_type", default: "inclusion", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "shown", default: true, null: false
    t.integer "criteria_order"
    t.bigint "patient_id", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "entered_by_id"
    t.bigint "criteria_variable_id"
    t.string "criteria_category", default: "primary", null: false
    t.index ["criteria_variable_id"], name: "index_variable_values_on_criteria_variable_id"
    t.index ["entered_by_id"], name: "index_variable_values_on_entered_by_id"
    t.index ["patient_id", "name"], name: "index_variable_values_on_patient_id_and_name"
    t.index ["patient_id", "variable_type", "criteria_order"], name: "index_vv_on_patient_type_order"
    t.index ["patient_id"], name: "index_variable_values_on_patient_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.jsonb "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "studies"
  add_foreign_key "campaign_documents", "campaigns"
  add_foreign_key "campaigns", "studies"
  add_foreign_key "complementary_informations", "patients"
  add_foreign_key "consents", "patients"
  add_foreign_key "contacts", "studies"
  add_foreign_key "criteria_profiles", "studies"
  add_foreign_key "criteria_profiles", "users"
  add_foreign_key "criteria_variables", "criteria_profiles"
  add_foreign_key "local_parameters", "countries"
  add_foreign_key "patient_declarations", "criteria_variables", on_delete: :nullify
  add_foreign_key "patient_declarations", "patients"
  add_foreign_key "patient_declarations", "users", column: "recorded_by_id"
  add_foreign_key "patients", "studies"
  add_foreign_key "results", "studies"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "sponsor_reps", "sponsors"
  add_foreign_key "studies", "sponsors"
  add_foreign_key "trial_center_branch_reps", "trial_center_branches"
  add_foreign_key "trial_center_branches", "trial_center_facilities"
  add_foreign_key "trial_cities", "studies"
  add_foreign_key "users", "roles"
  add_foreign_key "variable_values", "criteria_variables", on_delete: :nullify
  add_foreign_key "variable_values", "patients"
  add_foreign_key "variable_values", "users", column: "entered_by_id"
end
