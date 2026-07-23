class AddStudyTypeAndApprovalsToStudies < ActiveRecord::Migration[8.0]
  # study_type splits the two shapes of research the platform handles:
  # observational (no intervention assigned by the investigator — the approval
  # that matters is the ethics committee's) and interventional (a drug/device is
  # administered — the local health authority, INVIMA in Colombia, must approve).
  # Hence one approval flag per type rather than a single generic one.
  def up
    add_column :studies, :study_type, :string
    add_column :studies, :local_health_authority_approved, :boolean, default: false, null: false
    add_column :studies, :committee_approved, :boolean, default: false, null: false

    # Every pre-existing study carries a study_phase (I–IV), which only
    # interventional research has — so that is the truthful backfill.
    execute "UPDATE studies SET study_type = 'interventional' WHERE study_type IS NULL"
  end

  def down
    remove_column :studies, :committee_approved
    remove_column :studies, :local_health_authority_approved
    remove_column :studies, :study_type
  end
end
