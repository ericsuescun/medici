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
  end

  def update
    save_values!
    redirect_to patient_criteria_assessment_path(@patient, criteria_profile_id: @profile.id),
                notice: t("criteria_assessments.updated")
  end

  private

  def set_patient
    @patient = Patient.find(params[:patient_id])
  end

  def set_profile
    @profile = CriteriaProfile.find(params[:criteria_profile_id])
  end

  def ordered_variables
    @profile.criteria_variables.select(&:enabled).sort_by { |cv| [ cv.variable_type, cv.criteria_order || 0 ] }
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
