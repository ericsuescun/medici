class AddCriteriaCategoryToCriteriaVariables < ActiveRecord::Migration[8.0]
  # Splits eligibility rules into the ones that decide and the ones that inform.
  #
  # A *primary* criterion is decisive: it is what the recruitment score is
  # computed from, and therefore what tells a rep whether an interested patient
  # is ready to become a candidate. A *secondary* criterion still gets measured
  # and still shows in the verdict, but it never moves the score, so it can
  # never on its own promote (or hold back) a patient.
  #
  # Both tables get the column because VariableValue is a point-in-time snapshot
  # of the rule it answers (same shape as CriteriaVariable, by design) — an
  # answer must record how decisive the rule was when it was captured.
  #
  # Backfill: "primary" for every existing row. Before this change every enabled
  # criterion counted equally toward the verdict, so treating them all as
  # decisive is the only backfill that leaves existing profiles behaving exactly
  # as they did.
  def change
    add_column :criteria_variables, :criteria_category, :string, default: "primary", null: false
    add_column :variable_values, :criteria_category, :string, default: "primary", null: false
  end
end
