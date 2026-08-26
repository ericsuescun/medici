# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'factory_bot'

# ---------------------------------------------------------------------------
# REFERENCE DATA — every environment, production included.
# Idempotent, and creates nothing that isn't required for the app to function.
# ---------------------------------------------------------------------------

# Roles + the default permission matrix (never overwrites admin customizations).
require_relative 'seeds/roles_and_permissions'
RolesAndPermissionsSeeder.seed!

# Study categories (therapeutic areas) — the study form's dropdown, the public
# home-page filter, and the navbar search all read these.
require_relative 'seeds/categories'
CategoriesSeeder.seed!

# Country-specific configuration (Colombia's health authority = INVIMA) — the
# study form names the regulator by reading this.
require_relative 'seeds/local_parameters'
LocalParametersSeeder.seed!

# ---------------------------------------------------------------------------
# SAMPLE DATA — DEVELOPMENT ONLY, and the guard is the whole point.
#
# `bin/rails db:seed` runs automatically on `db:setup` and can be run by hand on
# any dyno, so anything below this line would otherwise be one command away from
# production. It creates staff accounts with the hard-coded password '12345678'
# and a few hundred fake patients; neither belongs in a database holding real
# people's health data. Do not replace this guard with a comment.
# ---------------------------------------------------------------------------
unless Rails.env.development?
  puts "Seeds: reference data only (#{Rails.env} — sample data is development-only)."
  return
end

puts "\nSeeds: development sample data..."

# --- Lookup tables -----------------------------------------------------------
require_relative 'seeds/create_id_types'
require_relative 'seeds/create_medications'
require_relative 'seeds/create_countries'

# --- Named admin accounts ----------------------------------------------------
# Real addresses so the team can log in as themselves. Password is '12345678'
# for all of them, which is exactly why this sits behind the development guard.
[ [ 'edsuescun@gmail.com', 'Eric', 'Suescun' ],
  [ 'nlecuona@gmail.com', 'Nathalia', 'Lecuona' ],
  [ 'agiraldo@gmail.com', 'Alejandro', 'Giraldo' ]
].each do |email, first, last|
  next if User.exists?(email: email)

  FactoryBot.create(:user, :admin, email: email,
                    password: '12345678', password_confirmation: '12345678',
                    firstname: first, lastname: last)
end
puts "  admins:      #{User.admins.count}"

# --- Cities ------------------------------------------------------------------
# A fixed Colombian pool, reused rather than generated. Faker's
# `Nation.unique.capital_city` was the old approach and it (a) put Kathmandu in
# a Colombian trial network and (b) raises RetryLimitExceeded once the unique
# pool runs dry, which a few dozen branches will do.
CITIES = Patient::PRINCIPAL_CITIES.map { |name| City.find_or_create_by!(name: name) }
puts "  cities:      #{City.count}"

# --- Trial centres, their branches, and the reps who work in them ------------
if TrialCenterFacility.count.zero?
  20.times do
    facility = FactoryBot.create(:trial_center_facility)
    facility.cities << CITIES.sample

    rand(1..3).times do
      branch = FactoryBot.create(:trial_center_branch, trial_center_facility: facility)
      branch.cities << CITIES.sample
      rand(1..2).times do
        FactoryBot.create(:user, userable: FactoryBot.build(:trial_center_branch_rep, trial_center_branch: branch))
      end
    end
  end
end
puts "  facilities:  #{TrialCenterFacility.count} (#{TrialCenterBranch.count} branches)"

# --- Sponsors, their reps, and a studies graph -------------------------------
# Patients are created here as plain `Patient` rows, NOT as Users. Patients have
# no accounts at all (see CLAUDE.md) — `User.patients` is permanently empty and
# the old `FactoryBot.create(:user, :patient)` / `User.patients.each` blocks that
# used to live here seeded a model the app no longer has.
if Study.count < 10
  branch_ids = TrialCenterBranch.ids

  15.times do
    sponsor = FactoryBot.create(:sponsor, international: rand < 0.3)
    rand(1..3).times do
      FactoryBot.create(:user, userable: FactoryBot.build(:sponsor_rep, sponsor: sponsor))
    end

    FactoryBot.create_list(:study, rand(1..4), sponsor: sponsor) do |study|
      study.trial_center_branches << TrialCenterBranch.where(id: branch_ids.sample(rand(1..3)))
      study.categories << Category.order("RANDOM()").limit(rand(1..3))
      # Mostly recruiting, a few completed (completed reads as "disabled"), with
      # a small recruitment goal so the progress bar shows meaningful fill...
      study.update!(study_status: rand < 0.8 ? "recruiting" : "completed",
                    sample_size: rand(8..20))
      # ...and patients spread across the lifecycle states that fill it:
      # participants (green), candidates (yellow), interested (red).
      rand(1..4).times { FactoryBot.create(:patient, :participant, study: study) }
      rand(0..4).times { FactoryBot.create(:patient, :candidate, study: study) }
      rand(2..5).times { FactoryBot.create(:patient, study: study) }
      FactoryBot.create_list(:article, rand(1..3), study: study)
      FactoryBot.create_list(:contact, rand(1..2), study: study)
      FactoryBot.create_list(:result, rand(1..4), study: study)
    end
  end
end
puts "  sponsors:    #{Sponsor.count} (#{Study.count} studies, #{Patient.count} patients)"

# --- Leads: patients as the PUBLIC form actually creates them -----------------
# Everything above is a FactoryBot patient with a Faker name, which is the shape
# a trial centre rep types in — not the shape most patients arrive in. Somebody
# who presses "¡Quiero participar!" leaves a phone number and nothing else: no
# name, no dob, no sex (ParticipationRequestsController permits `:contact_number,
# :email` and nothing more). They are the ones who most need a call back, and
# until 2026-08-25 the dev graph contained none of them, so the recruitment page
# never showed the case it exists for.
#
# In its own block rather than inside the studies loop above, which is guarded by
# `if Study.count < 10` — this way an existing development database gets its
# leads on the next `db:seed` instead of needing a reset.
Study.recruiting.includes(:patients).find_each do |study|
  next if study.patients.any? { |p| p.firstname.nil? } # already has leads

  rand(1..3).times do
    FactoryBot.create(
      :patient, :lead,
      study: study,
      # The public form asks for a coarse city from a picker; plenty of people
      # skip it, and some are filled in by a relative rather than the patient.
      reported_city: rand < 0.7 ? Patient::PRINCIPAL_CITIES.sample : nil,
      submitted_by_proxy: rand < 0.2
    )
  end
end
puts "  leads:       #{Patient.where(firstname: nil).count} with no name (public-form shape)"

# --- Eligibility profiles ----------------------------------------------------
# One profile per study, cycling four therapeutic areas. Each is 25 criteria
# with a FIXED primary set of 5 (2 inclusion + 3 exclusion) — those five are the
# only ones the patient questionnaire asks, and the only ones that are scored.
require_relative 'seeds/example_criteria_profiles'
created = ExampleCriteriaProfiles.seed!
puts "  profiles:    #{CriteriaProfile.count} (#{created} new, #{CriteriaVariable.count} criteria)"

# --- The public step-2 questionnaire -----------------------------------------
# Switched on for a third of the recruiting studies. The flag means "this
# study's question wording is CEI-approved participant material", so it is
# deliberately not on by default — but it has no UI yet, so without seeding it
# the public questionnaire is unreachable in development.
Study.recruiting.order(:id).each_with_index do |study, i|
  next unless (i % 3).zero?
  next if study.criteria_profile.nil?

  study.update!(patient_self_report_enabled: true)

  # Patients answer the questions themselves. Where their answers satisfy every
  # primary criterion this auto-triages them exactly as SelfReportsController
  # does — attributed to the system, because it was.
  #
  # NAMELESS LEADS GO FIRST, and one of them answers everything (`complete:`).
  # A lead who qualifies on their own answers is precisely the row the
  # recruitment page exists for: no name, a phone number, sitting in `candidate`
  # with a full questionnaire, waiting for somebody to ring them. Leaving it to
  # chance meant the graph usually had none.
  # Only patients who have not answered yet: `declare!` appends rows, so without
  # this a second `db:seed` would give the same person two sets of answers.
  interested = study.patients.where(state: "interested")
                    .where.missing(:patient_declarations)
  leads = interested.where(firstname: nil).to_a
  named = interested.where.not(firstname: nil).limit(1).to_a

  ExampleCriteriaProfiles.declare!(study.criteria_profile, leads.first(1), complete: true)
  ExampleCriteriaProfiles.declare!(study.criteria_profile, leads.drop(1).first(1) + named)
end
puts "  self-report: #{Study.where(patient_self_report_enabled: true).count} studies, " \
     "#{PatientDeclaration.count} declarations"

# --- The worked example ------------------------------------------------------
# Its own study + one demo patient per recruitment outcome, printed, so the
# primary/secondary split is visible without clicking through anything.
require_relative 'seeds/example_seborrheic_dermatitis_profile'
puts "\n  Worked example (dermatitis seborreica):"
ExampleSeborrheicDermatitisProfile.report!

puts "\nSeeds done. Log in as edsuescun@gmail.com / 12345678\n\n"
