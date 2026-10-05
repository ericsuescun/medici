namespace :patients do
  # Apply the criteria rules to patients who predate them — or who predate a
  # change to them.
  #
  # Patient#sync_state_with_criteria! runs automatically whenever EVIDENCE
  # changes (a rep saves the assessment form, a patient submits the
  # questionnaire). It deliberately does not run when a RULE changes: editing
  # one CriteriaVariable re-judges every patient on that study, and silently
  # moving hundreds of people because somebody fixed a threshold is not a thing
  # a form submission should do. This task is how that gets applied, when
  # somebody decides to.
  #
  # It is also how patients are caught up after the 2026-10-04 rename
  # migration, which renamed values and moved nobody, on purpose.
  #
  # Dry by default. The dry run executes the REAL sync inside a transaction and
  # rolls it back, rather than re-deriving the decision here: a second
  # implementation of "what would happen" is exactly the kind of thing that
  # drifts from the first and then lies to whoever is deciding whether to run it.
  desc "Re-apply the criteria rules to every patient's state (APPLY=yes to write)"
  task sync_states: :environment do
    apply = ENV["APPLY"] == "yes"
    moved = []

    scope = Patient.includes(:variable_values, :patient_declarations,
                             study: { criteria_profile: :criteria_variables })

    sync = lambda do
      scope.find_each do |patient|
        before = patient.state
        patient.sync_state_with_criteria!
        next if patient.state == before

        moved << [ patient.participant_code, before, patient.state,
                   patient.study&.display_title.to_s.truncate(50) ]
      end
    end

    if apply
      sync.call
    else
      ActiveRecord::Base.transaction do
        sync.call
        raise ActiveRecord::Rollback
      end
    end

    moved.each { |code, before, after, study| puts format("%-12s %-11s -> %-11s  %s", code, before, after, study) }
    puts(apply ? "#{moved.size} patient(s) moved." : "#{moved.size} patient(s) WOULD move. Re-run with APPLY=yes.")
  end
end
