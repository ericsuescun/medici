class CreatePatientDeclarations < ActiveRecord::Migration[8.0]
  # Testimony, not measurement. What the patient (or a rep on the phone)
  # DECLARED, kept apart from variable_values — the investigator-verified
  # measurements that feed the promotion gate.
  #
  # Deliberately absent: comparison_type, reference_value_1/2, variable_type,
  # criteria_category — and the answer column is named `answer`, not `value`.
  # Consequences, verified against the code: `include CriteriaComparable` is
  # impossible (it reads comparison_type/reference_value_1), EligibilityResult's
  # checks can't wrap it (they read variable_type/criteria_category), and
  # CriteriaProfile#evaluate's `answer.value` raises. A declaration can only be
  # scored by handing its raw `answer` to the LIVE rule
  # (CriteriaVariable#satisfied_by?), which is exactly what the triage
  # evaluation does. Anyone shortcutting the separation gets a NoMethodError,
  # not a silently wrong verdict. Do not add those columns.
  def change
    create_table :patient_declarations do |t|
      t.references :patient, null: false, foreign_key: true
      # nullify: deleting a rule keeps the testimony as a historical record.
      t.references :criteria_variable, foreign_key: { on_delete: :nullify }
      # The staff user who transcribed a phone/paper answer; NULL means the
      # patient entered it themselves through the public questionnaire.
      t.references :recorded_by, foreign_key: { to_table: :users }
      # Snapshot of the exact patient-language question that was shown.
      t.text :prompt, null: false
      # Encrypted (non-deterministic) in the model — health data, never queried by value.
      t.string :answer
      # Only what the questionnaire needs to render/parse; never enough to score.
      t.string :value_type, null: false
      t.text :qualitative_scale, array: true, default: [], null: false
      # "No sé / prefiero no responder" is a first-class answer, not a blank.
      t.boolean :declined, default: false, null: false
      # public_form (patient, in-session) | interview (rep on the phone/paper).
      t.string :capture_mode, null: false, default: "public_form"
      t.datetime :declared_at, null: false
      # A re-answer supersedes rather than overwrites — testimony is append-only.
      t.datetime :superseded_at

      t.timestamps
    end

    # One LIVE declaration per rule per patient (NULLs compare distinct, so
    # rule-less historical rows never collide).
    add_index :patient_declarations, [ :patient_id, :criteria_variable_id ],
              unique: true, where: "superseded_at IS NULL",
              name: "index_live_declarations_on_patient_and_variable"
  end
end
