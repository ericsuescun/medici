class CriteriaAssessmentsController < SecureApplicationController
  before_action :set_patient
  before_action :set_profile
  # Assessing a patient's criteria is editing the patient's clinical data.
  before_action -> { authorize(@patient, :update?) }

  def show
    @variables = ordered_variables
    # Prefill by FK (falls back to name for legacy rows), so a renamed rule still
    # shows the value the patient already has for it.
    values = @patient.variable_values.to_a
    @values_by_var = values.index_by(&:criteria_variable_id)
    @values_by_name = values.reject(&:criteria_variable_id).index_by(&:name)
    @result = @profile.evaluate(@patient)
    # What the patient declared about themselves (questionnaire/phone) — shown
    # as testimony beside each rule so the rep can verify rather than re-ask.
    # Never evaluated here: only investigator-recorded values feed @result.
    @declarations_by_variable = @patient.patient_declarations.live.index_by(&:criteria_variable_id)
  end

  def update
    save_values!
    redirect_to patient_criteria_assessment_path(@patient, criteria_profile_id: @profile.id),
                notice: t("criteria_assessments.updated")
  end

  private

  # Row-level access, the same recipe as the other patient sub-resources (
  # notes, complementary information, briefing): load through `policy_scope`, so
  # a rep reaching for another centre's patient gets a 404 rather than the
  # record. This used to be a bare `Patient.find`, which let any rep with the
  # class-level `can_edit` permission read AND write any patient's clinical
  # values — and since those values are what the promotion gate reads, writing
  # them was enough to open the gate for the patient's own rep.
  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  # Always the patient's OWN study's profile. A criteria_profile_id that does not
  # match is refused rather than honoured: assessing a patient against one rule
  # set while `Patient#primary_criteria_met?` gates on another is how the page
  # and the gate end up contradicting each other.
  def set_profile
    @profile = @patient.study&.criteria_profile
    raise ActiveRecord::RecordNotFound if @profile.nil?

    requested = params[:criteria_profile_id]
    raise ActiveRecord::RecordNotFound if requested.present? && requested.to_s != @profile.id.to_s
  end

  # Gated by the parent patient, not the permission matrix (see
  # ComplementaryInformationsController).
  def authorization_model
    nil
  end

  # Decisive criteria first: they are what the recruitment score is built from,
  # so they are what a rep should be asked to measure first.
  def ordered_variables
    @profile.criteria_variables.select(&:enabled).sort_by do |cv|
      [ cv.criteria_category == "primary" ? 0 : 1, cv.variable_type, cv.criteria_order || 0 ]
    end
  end

  # Upsert one VariableValue per submitted variable, keyed by the rule's FK so a
  # renamed rule updates the same answer row instead of orphaning it. Copies the
  # rule onto the value (the snapshot design), refreshing the snapshot `name` to
  # the rule's current name on every capture.
  def save_values!
    @profile.criteria_variables.each do |cv|
      raw = params.dig(:values, cv.id.to_s)
      next if raw.blank?

      record = find_or_init_value(cv)
      # Attribute the first capture to the acting user; later edits are tracked by
      # PaperTrail's whodunnit, so we don't overwrite the original recorder here.
      record.entered_by ||= current_user
      record.assign_attributes(
        criteria_variable: cv,
        name: cv.name,
        value: raw.to_s,
        value_type: cv.value_type, comparison_type: cv.comparison_type, variable_type: cv.variable_type,
        criteria_category: cv.criteria_category,
        reference_value_1: cv.reference_value_1, reference_value_2: cv.reference_value_2,
        qualitative_value: cv.qualitative_value, qualitative_scale: cv.qualitative_scale,
        criteria_order: cv.criteria_order
      )
      record.save!
    end
  end

  # Prefer the FK match; adopt a legacy name-matched row (and stamp its FK) if the
  # answer predates the FK; otherwise start a fresh answer.
  def find_or_init_value(cv)
    @patient.variable_values.find_by(criteria_variable_id: cv.id) ||
      @patient.variable_values.where(criteria_variable_id: nil).find_by(name: cv.name) ||
      @patient.variable_values.build
  end
end
