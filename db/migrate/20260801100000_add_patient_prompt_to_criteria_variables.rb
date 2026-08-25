class AddPatientPromptToCriteriaVariables < ActiveRecord::Migration[8.0]
  # The patient-language question for a rule ("¿Cuál es su edad?"), written by
  # the profile's author. Its presence is what makes a rule patient-answerable:
  # the public questionnaire renders ONLY this prompt — never the rule's name,
  # thresholds or rule_summary, which would leak the protocol's criteria to the
  # person being screened. No prompt, no question; that makes the leak
  # structurally impossible rather than a rendering discipline.
  def change
    add_column :criteria_variables, :patient_prompt, :text
  end
end
