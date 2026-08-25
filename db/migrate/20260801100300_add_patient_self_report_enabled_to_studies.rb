class AddPatientSelfReportEnabledToStudies < ActiveRecord::Migration[8.0]
  # Per-study rollout switch for the public self-report questionnaire (step 2 of
  # the participation flow). Default OFF: turning it on means the study's
  # patient_prompt wording has been approved as participant-facing material
  # (Res. 2378 Anexo Técnico — materiales entregados a los participantes), so it
  # is an ethics/product decision per study, not a feature flag a rep flips.
  # Deliberately separate from committee_approved/local_health_authority_approved,
  # which are study approvals, not participant-material approvals.
  def change
    add_column :studies, :patient_self_report_enabled, :boolean, default: false, null: false
  end
end
