class LinkVariableValuesToCriteriaVariables < ActiveRecord::Migration[8.0]
  # The eligibility engine used to match a patient's answers (VariableValue) to a
  # profile's rules (CriteriaVariable) by `name` alone — no FK. Renaming a rule
  # silently orphaned every existing answer (it read as "unmeasured"). This adds
  # the missing link so the match survives a rename.
  #
  # on_delete: :nullify — deleting a rule must NOT delete the patient's historical
  # answer. The answer keeps its own snapshot columns (name, comparison, etc.), so
  # it stays a truthful record of what was measured even if the rule is gone.
  def up
    add_reference :variable_values, :criteria_variable,
                  null: true, index: true,
                  foreign_key: { on_delete: :nullify }

    # Backfill: connect each existing answer to its rule by name, scoped to the
    # profile of the patient's study (names are only unique within a profile).
    execute <<~SQL
      UPDATE variable_values vv
      SET criteria_variable_id = cv.id
      FROM patients p, criteria_profiles cp, criteria_variables cv
      WHERE vv.patient_id = p.id
        AND cp.study_id = p.study_id
        AND cv.criteria_profile_id = cp.id
        AND cv.name = vv.name
        AND vv.criteria_variable_id IS NULL
    SQL
  end

  def down
    remove_reference :variable_values, :criteria_variable, foreign_key: true
  end
end
