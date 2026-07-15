
# Patients are records now, not users: nothing signs up, and the patient role has
# no permissions on anything. The leftover accounts are logins that can never do
# anything useful, so they go — but the Patient records they wrapped stay.
#
# Must run AFTER AddStudyToPatients and MoveConsentsToPatients: both read the
# study/consent links off these very users. Deleting first would lose them.
#
# Raw SQL on purpose. `User delegated_type :userable, dependent: :destroy` means
# destroying a patient User through the model would destroy its Patient too —
# exactly the data we are keeping.
class RemovePatientUserAccounts < ActiveRecord::Migration[8.0]
  def up
    # Refuse to run if the study backfill missed anyone: deleting the account
    # would then throw away the only record of which study they came for.
    stranded = select_value(<<~SQL).to_i
      SELECT COUNT(*)
        FROM users u
        JOIN patients p ON p.id = u.userable_id
       WHERE u.userable_type = 'Patient'
         AND p.study_id IS NULL
         AND EXISTS (SELECT 1 FROM studies_users su WHERE su.user_id = u.id)
    SQL

    if stranded.positive?
      raise ActiveRecord::MigrationError,
            "#{stranded} patient account(s) still hold a study link that never reached patients.study_id. " \
            "Run AddStudyToPatients first — refusing to delete accounts whose study would be lost."
    end

    execute "DELETE FROM studies_users WHERE user_id IN (SELECT id FROM users WHERE userable_type = 'Patient')"
    execute "DELETE FROM users WHERE userable_type = 'Patient'"
  end

  # The accounts are gone for good: passwords are one-way and there is nothing to
  # rebuild them from. The Patient records — the data that matters — are intact.
  def down
    raise ActiveRecord::IrreversibleMigration,
          "Patient user accounts cannot be recreated (their credentials are not recoverable). " \
          "The Patient records themselves were never deleted."
  end
end
