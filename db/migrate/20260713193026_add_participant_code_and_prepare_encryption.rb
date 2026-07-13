class AddParticipantCodeAndPrepareEncryption < ActiveRecord::Migration[8.0]
  # Pseudonymization groundwork (INVIMA Anexo Técnico Tabla 7):
  #  - participant_code: a non-identifying code so research/eligibility data can be
  #    linked back to a patient by code rather than by identity.
  #  - dob date -> string: ActiveRecord::Encryption stores ciphertext (a string),
  #    which a `date` column cannot hold. Other encrypted columns are already
  #    unlimited `character varying`, which holds ciphertext fine.
  def up
    add_column :patients, :participant_code, :string
    add_index :patients, :participant_code, unique: true

    # date -> varchar needs an explicit cast in Postgres.
    execute "ALTER TABLE patients ALTER COLUMN dob TYPE character varying USING dob::text"

    backfill_participant_codes
    backfill_patient_identity_from_user
  end

  def down
    execute "ALTER TABLE patients ALTER COLUMN dob TYPE date USING dob::date"
    remove_index :patients, :participant_code
    remove_column :patients, :participant_code
  end

  private

  # Raw SQL (not the Patient model) so encryption/paper_trail callbacks don't fire.
  def backfill_participant_codes
    say_with_time "Backfilling participant codes" do
      used = select_values("SELECT participant_code FROM patients WHERE participant_code IS NOT NULL").to_set
      ids = select_values("SELECT id FROM patients WHERE participant_code IS NULL")
      ids.each do |id|
        code = nil
        loop do
          code = "P-#{SecureRandom.alphanumeric(8).upcase}"
          break unless used.include?(code)
        end
        used << code
        execute("UPDATE patients SET participant_code = #{quote(code)} WHERE id = #{id.to_i}")
      end
      ids.size
    end
  end

  # Patient now owns its identity (firstname/lastname/email) instead of delegating
  # to User. Copy existing patients' identity from their User so names don't vanish
  # for records created before this change. Raw SQL keeps it plaintext for now;
  # `rails patients:reencrypt` (post-deploy) encrypts it at rest.
  def backfill_patient_identity_from_user
    say_with_time "Backfilling patient identity from user" do
      execute(<<~SQL.squish)
        UPDATE patients SET
          firstname = COALESCE(NULLIF(patients.firstname, ''), u.firstname),
          lastname  = COALESCE(NULLIF(patients.lastname, ''), u.lastname),
          email     = COALESCE(NULLIF(patients.email, ''), u.email)
        FROM users u
        WHERE u.userable_type = 'Patient' AND u.userable_id = patients.id
      SQL
    end
  end
end
