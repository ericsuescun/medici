require "test_helper"

class StudiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @study = studies(:one)
  end

  test "should get index" do
    get studies_url
    assert_response :success
  end

  test "should get new" do
    get new_study_url
    assert_response :success
  end

  test "should create study" do
    assert_difference("Study.count") do
      post studies_url, params: { study: { approved_at: @study.approved_at, scientific_title: @study.cientific_title, control_group: @study.control_group, ethical_approval_at: @study.ethical_approval_at, ethical_committee: @study.ethical_cometee, exclusion_criteria: @study.exclusion_criteria, first_patient_at: @study.first_patient_at, global_ending_at: @study.global_ending_at, inclusion_criteria: @study.inclusion_criteria, keywords: @study.keywords, local_unique_register: @study.local_unique_register, main_intervention: @study.main_intervention, medical_preexistences: @study.medical_preexistencies, medication: @study.medication, participant_ending_age: @study.participant_ending_age, participant_starting_age: @study.participant_starting_age, pathology: @study.pathology, public_title: @study.public_title, registered_at: @study.registrated_at, review_user_id: @study.review_user_id, reviewed: @study.reviewed, sample_size: @study.sample_size, sex: @study.sex, sponsor_id: @study.sponsors_id, started_at: @study.started_at, study_phase: @study.study_phase, study_status: @study.study_status, study_type: @study.study_type } }
    end

    assert_redirected_to study_url(Study.last)
  end

  test "should show study" do
    get study_url(@study)
    assert_response :success
  end

  test "should get edit" do
    get edit_study_url(@study)
    assert_response :success
  end

  test "should update study" do
    patch study_url(@study), params: { study: { approved_at: @study.approved_at, scientific_title: @study.cientific_title, control_group: @study.control_group, ethical_approval_at: @study.ethical_approval_at, ethical_committee: @study.ethical_cometee, exclusion_criteria: @study.exclusion_criteria, first_patient_at: @study.first_patient_at, global_ending_at: @study.global_ending_at, inclusion_criteria: @study.inclusion_criteria, keywords: @study.keywords, local_unique_register: @study.local_unique_register, main_intervention: @study.main_intervention, medical_preexistences: @study.medical_preexistencies, medication: @study.medication, participant_ending_age: @study.participant_ending_age, participant_starting_age: @study.participant_starting_age, pathology: @study.pathology, public_title: @study.public_title, registered_at: @study.registrated_at, review_user_id: @study.review_user_id, reviewed: @study.reviewed, sample_size: @study.sample_size, sex: @study.sex, sponsor_id: @study.sponsors_id, started_at: @study.started_at, study_phase: @study.study_phase, study_status: @study.study_status, study_type: @study.study_type } }
    assert_redirected_to study_url(@study)
  end

  test "should destroy study" do
    assert_difference("Study.count", -1) do
      delete study_url(@study)
    end

    assert_redirected_to studies_url
  end
end
