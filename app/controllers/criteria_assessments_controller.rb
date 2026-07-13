class CriteriaAssessmentsController < SecureApplicationController
  before_action :set_patient
  before_action :set_profile
  # Assessing a patient's criteria is editing the patient's clinical data.
  before_action -> { authorize(@patient, :update?) }

  def show
    @variables = ordered_variables
    @values_by_name = @patient.variable_values.index_by(&:name)
    @result = @profile.evaluate(@patient)
  end

  def update
    save_values!
    redirect_to patient_criteria_assessment_path(@patient, criteria_profile_id: @profile.id),
                notice: "Evaluación de criterios actualizada."
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

  # Upsert one VariableValue per submitted variable (keyed by variable id, since
  # names contain spaces/parens). Copies the rule onto the value (the snapshot
  # design), matched to the profile by name.
  def save_values!
    @profile.criteria_variables.each do |cv|
      raw = params.dig(:values, cv.id.to_s)
      next if raw.blank?

      record = @patient.variable_values.find_or_initialize_by(name: cv.name)
      # Attribute the first capture to the acting user; later edits are tracked by
      # PaperTrail's whodunnit, so we don't overwrite the original recorder here.
      record.entered_by ||= current_user
      record.assign_attributes(
        value: raw.to_s,
        value_type: cv.value_type, comparison_type: cv.comparison_type, variable_type: cv.variable_type,
        reference_value_1: cv.reference_value_1, reference_value_2: cv.reference_value_2,
        qualitative_value: cv.qualitative_value, qualitative_scale: cv.qualitative_scale,
        criteria_order: cv.criteria_order
      )
      record.save!
    end
  end
end
