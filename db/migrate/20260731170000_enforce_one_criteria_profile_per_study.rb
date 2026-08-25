class EnforceOneCriteriaProfilePerStudy < ActiveRecord::Migration[8.0]
  # A study's eligibility rules are singular — `Study has_one :criteria_profile`,
  # and StudiesController#set_criteria_profile detaches any existing profile
  # before attaching a new one. But nothing enforced it: CriteriaProfilesController
  # permits :study_id directly against a `Study.all` select, so two profiles could
  # point at the same study.
  #
  # That became dangerous when the criteria profile started gating patient
  # promotion (Patient#primary_criteria_met?): `has_one` emits LIMIT 1 with no
  # ORDER BY, so which of the two answered was physical row order, and it flips
  # when a row is merely updated. A study whose duplicate happens to have no
  # primary criteria evaluates to "nothing decisive to check" and lets patients
  # through the gate with zero criteria recorded.
  #
  # This detaches duplicates rather than deleting them: study_id becomes NULL,
  # which is a valid state (a profile with no study is a reusable template), so
  # no rules and no patient answers are lost. The survivor is the profile with
  # the most criteria variables — the one actually in use — with the lowest id
  # as tie-break, matching the association's new `order(:id)`.
  def up
    duplicates = select_all(<<~SQL).to_a
      SELECT study_id FROM criteria_profiles
      WHERE study_id IS NOT NULL
      GROUP BY study_id HAVING COUNT(*) > 1
    SQL

    duplicates.each do |row|
      study_id = row["study_id"]
      keeper = select_value(<<~SQL)
        SELECT p.id FROM criteria_profiles p
        LEFT JOIN criteria_variables v ON v.criteria_profile_id = p.id
        WHERE p.study_id = #{quote(study_id)}
        GROUP BY p.id
        ORDER BY COUNT(v.id) DESC, p.id ASC
        LIMIT 1
      SQL

      detached = select_values(
        "SELECT id FROM criteria_profiles WHERE study_id = #{quote(study_id)} AND id <> #{quote(keeper)}"
      )
      say "Study #{study_id}: keeping criteria profile #{keeper}, detaching #{detached.join(', ')}"
      execute "UPDATE criteria_profiles SET study_id = NULL WHERE id IN (#{detached.map { |i| quote(i) }.join(', ')})"
    end

    add_index :criteria_profiles, :study_id,
              unique: true,
              where: "study_id IS NOT NULL",
              name: "index_criteria_profiles_on_study_id_unique"
  end

  def down
    remove_index :criteria_profiles, name: "index_criteria_profiles_on_study_id_unique"
  end
end
