require "application_system_test_case"

class StudiesTest < ApplicationSystemTestCase
  setup do
    @study = studies(:one)
  end

  test "visiting the index" do
    visit studies_url
    assert_selector "h1", text: "Studies"
  end

  test "should create study" do
    visit studies_url
    click_on "New study"

    fill_in "Approved at", with: @study.approved_at
    fill_in "Cientific title", with: @study.scientific_title
    fill_in "Control group", with: @study.control_group
    fill_in "Ethical approval at", with: @study.ethical_approval_at
    fill_in "Ethical committee", with: @study.ethical_committee
    fill_in "Exclusion criteria", with: @study.exclusion_criteria
    fill_in "First patient at", with: @study.first_patient_at
    fill_in "Global ending at", with: @study.global_ending_at
    fill_in "Inclusion criteria", with: @study.inclusion_criteria
    fill_in "Keywords", with: @study.keywords
    fill_in "Local unique register", with: @study.local_unique_register
    fill_in "Main intervention", with: @study.main_intervention
    fill_in "Medical preexistences", with: @study.medical_preexistences
    fill_in "Medication", with: @study.medication
    fill_in "Participant ending age", with: @study.participant_ending_age
    fill_in "Participant starting age", with: @study.participant_starting_age
    fill_in "Pathology", with: @study.pathology
    fill_in "Public title", with: @study.public_title
    fill_in "Registrated at", with: @study.registered_at
    fill_in "Review user", with: @study.review_user_id
    check "Reviewed" if @study.reviewed
    fill_in "Sample size", with: @study.sample_size
    fill_in "Sex", with: @study.sex
    fill_in "Sponsors", with: @study.sponsor_id
    fill_in "Started at", with: @study.started_at
    fill_in "Study phase", with: @study.study_phase
    fill_in "Study status", with: @study.study_status
    fill_in "Study type", with: @study.study_type
    click_on "Create Study"

    assert_text "Study was successfully created"
    click_on "Back"
  end

  test "should update Study" do
    visit study_url(@study)
    click_on "Edit this study", match: :first

    fill_in "Approved at", with: @study.approved_at
    fill_in "Cientific title", with: @study.scientific_title
    fill_in "Control group", with: @study.control_group
    fill_in "Ethical approval at", with: @study.ethical_approval_at
    fill_in "Ethical committee", with: @study.ethical_committee
    fill_in "Exclusion criteria", with: @study.exclusion_criteria
    fill_in "First patient at", with: @study.first_patient_at
    fill_in "Global ending at", with: @study.global_ending_at
    fill_in "Inclusion criteria", with: @study.inclusion_criteria
    fill_in "Keywords", with: @study.keywords
    fill_in "Local unique register", with: @study.local_unique_register
    fill_in "Main intervention", with: @study.main_intervention
    fill_in "Medical preexistences", with: @study.medical_preexistences
    fill_in "Medication", with: @study.medication
    fill_in "Participant ending age", with: @study.participant_ending_age
    fill_in "Participant starting age", with: @study.participant_starting_age
    fill_in "Pathology", with: @study.pathology
    fill_in "Public title", with: @study.public_title
    fill_in "Registered at", with: @study.registered_at
    fill_in "Review user", with: @study.review_user_id
    check "Reviewed" if @study.reviewed
    fill_in "Sample size", with: @study.sample_size
    fill_in "Sex", with: @study.sex
    fill_in "Sponsors", with: @study.sponsor_id
    fill_in "Started at", with: @study.started_at
    fill_in "Study phase", with: @study.study_phase
    fill_in "Study status", with: @study.study_status
    fill_in "Study type", with: @study.study_type
    click_on "Update Study"

    assert_text "Study was successfully updated"
    click_on "Back"
  end

  test "should destroy Study" do
    visit study_url(@study)
    click_on "Destroy this study", match: :first

    assert_text "Study was successfully destroyed"
  end
end
