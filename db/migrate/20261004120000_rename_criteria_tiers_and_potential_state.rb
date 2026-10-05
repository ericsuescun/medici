class RenameCriteriaTiersAndPotentialState < ActiveRecord::Migration[8.0]
  # Three vocabulary changes, decided together on 2026-10-04 because they
  # describe one lifecycle:
  #
  #   criteria_category  primary -> basic      the decisive few a patient can
  #                                            answer about themselves
  #                      secondary -> specific the investigator-measured rest
  #   patients.state     participant -> potential
  #
  # "Potential" is honest about what the app actually knows: the centre has
  # somebody worth approaching about a trial. Enrolment itself happens outside
  # the app (INVIMA multi-party consent), so calling the final state
  # "participant" claimed more than any row in here can support.
  #
  # PaperTrail `versions` rows are deliberately NOT rewritten — an audit trail
  # records what a value was called at the time, and a changeset saying
  # "prospect -> interested" or "candidate -> participant" is the truth about
  # what somebody saw on screen that day. Same decision as the 2026-07-22
  # prospect -> interested rename.
  #
  # Existing patients are NOT re-evaluated against the new automatic
  # transitions either; this only renames values. `rails patients:sync_states`
  # applies the new rules when the owner chooses to.
  CATEGORY_TABLES = %i[criteria_variables variable_values].freeze

  def up
    CATEGORY_TABLES.each do |table|
      change_column_default table, :criteria_category, "basic"
      execute "UPDATE #{table} SET criteria_category = 'basic' WHERE criteria_category = 'primary'"
      execute "UPDATE #{table} SET criteria_category = 'specific' WHERE criteria_category = 'secondary'"
    end

    # patients.state keeps its 'interested' default — only the FINAL state is
    # renamed, and nothing is created in it.
    execute "UPDATE patients SET state = 'potential' WHERE state = 'participant'"
  end

  def down
    CATEGORY_TABLES.each do |table|
      change_column_default table, :criteria_category, "primary"
      execute "UPDATE #{table} SET criteria_category = 'primary' WHERE criteria_category = 'basic'"
      execute "UPDATE #{table} SET criteria_category = 'secondary' WHERE criteria_category = 'specific'"
    end

    execute "UPDATE patients SET state = 'participant' WHERE state = 'potential'"
  end
end
