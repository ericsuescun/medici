
# Consents hung off User because the Ley 1581 authorization was captured during
# Devise sign-up. Patients no longer have accounts, so the authorization has to
# belong to the Patient it is about. Every consent ever written was a patient's
# habeas-data authorization (Users::RegistrationsController was the only writer),
# so this is a move, not a widening.
class MoveConsentsToPatients < ActiveRecord::Migration[8.0]
  def up
    add_reference :consents, :patient, foreign_key: true, index: true

    execute <<~SQL
      UPDATE consents
         SET patient_id = u.userable_id
        FROM users u
       WHERE u.id = consents.user_id
         AND u.userable_type = 'Patient'
    SQL

    # A consent is an immutable legal record: if one cannot be attributed to a
    # patient, stop and let a human decide. Never silently drop it.
    unmapped = select_value("SELECT COUNT(*) FROM consents WHERE patient_id IS NULL").to_i
    if unmapped.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{unmapped} consent(s) are not attributable to a Patient. These are legal records — " \
            "resolve them by hand before re-running this migration; it will not delete them."
    end

    change_column_null :consents, :patient_id, false
    remove_reference :consents, :user, foreign_key: true
  end

  def down
    add_reference :consents, :user, foreign_key: true, index: true

    execute <<~SQL
      UPDATE consents
         SET user_id = u.id
        FROM users u
       WHERE u.userable_type = 'Patient'
         AND u.userable_id = consents.patient_id
    SQL

    unmapped = select_value("SELECT COUNT(*) FROM consents WHERE user_id IS NULL").to_i
    if unmapped.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{unmapped} consent(s) have no corresponding patient User account to roll back to."
    end

    change_column_null :consents, :user_id, false
    remove_reference :consents, :patient, foreign_key: true
  end
end
