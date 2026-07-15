
# The study association used to live on the patient's User account
# (User has_and_belongs_to_many :studies), because a patient was only ever
# created through Devise sign-up. Patients are now plain records with no account,
# so the link has to move onto the patient itself.
class AddStudyToPatients < ActiveRecord::Migration[8.0]
  def up
    add_reference :patients, :study, foreign_key: true, index: true

    # Backfill from the old join. A patient could in principle be linked to more
    # than one study; `MIN(study_id)` picks deterministically rather than at
    # random. One study per patient is the model from here on.
    execute <<~SQL
      UPDATE patients
         SET study_id = link.study_id
        FROM (
          SELECT u.userable_id AS patient_id, MIN(su.study_id) AS study_id
            FROM users u
            JOIN studies_users su ON su.user_id = u.id
           WHERE u.userable_type = 'Patient'
        GROUP BY u.userable_id
        ) AS link
       WHERE link.patient_id = patients.id
    SQL
  end

  def down
    remove_reference :patients, :study
  end
end
