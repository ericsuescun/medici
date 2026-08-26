# Demo data for a REVIEW environment — deliberately not db/seeds.rb.
#
# db/seeds.rb is guarded by `unless Rails.env.development? ... return` and that
# guard must stay: everything below it is staff accounts with the password
# '12345678' and a few hundred fake patients. This task exists so a review or
# demo environment can be populated WITHOUT weakening that guard, and it makes
# the cost explicit rather than hiding it behind `rails db:seed`.
#
# WHAT IT WILL NOT DO
#   * It never deletes or rewrites anything that already exists. Studies,
#     patients, sponsors and users already in the database are left exactly as
#     they are; the task only fills gaps and adds new rows.
#   * It never attaches demo patients to a study it did not create, so a real
#     study's recruitment list stays real.
#
# WHAT MAKES THE DEMO DATA IDENTIFIABLE
#   Every row this task creates is marked in a way that is visible in the UI and
#   queryable afterwards: demo patients get a `participant_code` starting
#   "DEMO-" (plaintext, and shown as the patient's name when they have none),
#   demo studies and sponsors are prefixed "[DEMO]". `rake demo:purge` removes
#   exactly those and nothing else.
#
#   Usage (nothing happens without CONFIRM):
#     CONFIRM=yes rails demo:review_data
#     CONFIRM=yes MAX_STUDIES=5 rails demo:review_data
#     CONFIRM=yes RESET_PERMISSIONS=yes rails demo:review_data
#     CONFIRM=yes SELF_REPORT_ON_EXISTING=yes rails demo:review_data
#     CONFIRM=yes rails demo:purge
namespace :demo do
  DEMO_CODE_PREFIX = "DEMO-".freeze
  DEMO_TITLE_PREFIX = "[DEMO]".freeze
  DEMO_PASSWORD = "12345678".freeze

  desc "Fill a review environment with demo data, leaving existing records untouched (CONFIRM=yes)"
  task review_data: :environment do
    unless ENV["CONFIRM"] == "yes"
      abort <<~WARN
        Refusing to run without CONFIRM=yes.

        This creates accounts with the password '#{DEMO_PASSWORD}' and fake patient
        records in #{Rails.env}. On a database holding real people that is a
        decision, not a default.

            CONFIRM=yes rails demo:review_data
      WARN
    end

    # Fail here rather than half way through: in production the encryption keys
    # are ENV.fetch with no default, and a patient cannot be written without
    # them. Better a clear message than a stack trace after three sponsors.
    begin
      Patient.new(firstname: "probe").firstname
    rescue StandardError => e
      abort "Encryption is not configured (#{e.class}): set AR_ENCRYPTION_* before seeding."
    end

    require "factory_bot_rails"
    require Rails.root.join("db/seeds/roles_and_permissions")
    require Rails.root.join("db/seeds/example_criteria_profiles")

    max_studies = Integer(ENV.fetch("MAX_STUDIES", 5))

    puts "== Demo data for #{Rails.env} =="
    puts "   existing: #{Study.count} studies, #{Patient.count} patients, #{User.count} users"

    # --- Reference data ------------------------------------------------------
    # Idempotent and safe anywhere. `grant` never clobbers an existing row, so a
    # database seeded before a MATRIX change keeps the OLD permissions — which
    # is right in production (an admin's customisations survive a deploy) and
    # wrong for a demo of the new ones. RESET_PERMISSIONS re-applies the matrix.
    if ENV["RESET_PERMISSIONS"] == "yes"
      RolePermission.delete_all
      puts "   permissions: cleared, re-applying the current matrix"
    end
    RolesAndPermissionsSeeder.seed!

    require Rails.root.join("db/seeds/categories")
    require Rails.root.join("db/seeds/local_parameters")
    CategoriesSeeder.seed!
    LocalParametersSeeder.seed!

    # --- The extra admin -----------------------------------------------------
    email = ENV.fetch("ADMIN_EMAIL", "jose@gmail.com")
    if User.exists?(email: email)
      puts "   admin: #{email} already exists, left alone"
    else
      FactoryBot.create(:user, :admin, email: email,
                        password: DEMO_PASSWORD, password_confirmation: DEMO_PASSWORD,
                        firstname: "Jose", lastname: "Demo")
      puts "   admin: #{email} created (password #{DEMO_PASSWORD})"
    end

    owner = User.admins.first

    # --- Demo studies, up to the cap ----------------------------------------
    # Counts what is ALREADY there, so a database with one real study gets four
    # demo ones and the real study keeps its place.
    to_create = [ max_studies - Study.count, 0 ].max
    branch_ids = TrialCenterBranch.ids

    if to_create.zero?
      puts "   studies: #{Study.count} already >= MAX_STUDIES=#{max_studies}, creating none"
    else
      to_create.times do |i|
        sponsor = FactoryBot.create(:sponsor, name: "#{DEMO_TITLE_PREFIX} Patrocinador #{i + 1}")
        study = FactoryBot.create(:study, sponsor: sponsor,
                                  public_title: "#{DEMO_TITLE_PREFIX} Estudio de demostración #{i + 1}",
                                  study_status: "recruiting", sample_size: rand(8..20))
        study.trial_center_branches << TrialCenterBranch.where(id: branch_ids.sample(rand(1..2))) if branch_ids.any?
        study.categories << Category.order("RANDOM()").limit(1) if Category.any?
      end
      puts "   studies: #{to_create} demo studies created (total #{Study.count})"
    end

    demo_studies = Study.where("public_title LIKE ?", "#{DEMO_TITLE_PREFIX}%")

    # --- Criteria profiles ---------------------------------------------------
    # Every study that lacks one, INCLUDING a real study that has none: that is
    # what makes the eligibility engine, the recruitment score and the
    # questionnaire show anything at all. Shape comes from the seeder: 25
    # criteria with exactly 5 primary (2 inclusion + 3 exclusion), each of the
    # five patient-answerable and carrying a prompt, everything clinic-measured
    # left secondary. That 5 is a ceiling, not a ratio — the primary criteria
    # ARE the questions the patient is asked, and the form has to stay finishable.
    created = ExampleCriteriaProfiles.seed!(Study.all, owner: owner)
    puts "   profiles: #{created} created (#{CriteriaProfile.count} total, #{CriteriaVariable.count} criteria)"

    # --- The public questionnaire -------------------------------------------
    # Demo studies only, by default. `patient_self_report_enabled` means "this
    # study's question wording is CEI-approved participant material", so turning
    # it on for a REAL study points real applicants at questions nobody approved.
    # SELF_REPORT_ON_EXISTING=yes opts in deliberately.
    enable_on = ENV["SELF_REPORT_ON_EXISTING"] == "yes" ? Study.all : demo_studies
    enable_on.each do |study|
      next unless study.criteria_profile
      next if study.patient_self_report_enabled?

      study.patient_self_report_enabled = true
      next if study.save

      # A study that predates a later validation cannot be saved normally — the
      # first real one this hit had a blank short_title. Flipping ONE boolean is
      # no reason to demand an unrelated legacy field be fixed, and inventing a
      # value for it would be worse: that is somebody's real record. So the flag
      # is written past validation, and the row is named so it can be repaired
      # deliberately. save(validate: false) rather than update_column on purpose
      # — callbacks still run, so PaperTrail still records who changed what.
      warn "   ! study ##{study.id} is invalid for unrelated reasons " \
           "(#{study.errors.full_messages.join('; ')}) — flag written past validation"
      study.save(validate: false)
    end
    puts "   questionnaire: enabled on #{Study.where(patient_self_report_enabled: true).count} studies"

    # --- Demo patients, only on demo studies --------------------------------
    demo_studies.each do |study|
      next if study.patients.where("participant_code LIKE ?", "#{DEMO_CODE_PREFIX}%").any?

      2.times { demo_patient!(study, state: "participant") }
      2.times { demo_patient!(study, state: "candidate") }
      2.times { demo_patient!(study, state: "interested") }
      # The shape most people actually arrive in: a phone number and nothing
      # else. One of them answers every question and self-triages for real.
      leads = Array.new(3) { demo_patient!(study, state: "interested", lead: true) }
      next unless study.criteria_profile

      ExampleCriteriaProfiles.declare!(study.criteria_profile, leads.first(1), complete: true)
      ExampleCriteriaProfiles.declare!(study.criteria_profile, leads.drop(1).first(1))
    end

    puts "   patients: #{Patient.where('participant_code LIKE ?', "#{DEMO_CODE_PREFIX}%").count} demo " \
         "(#{Patient.count} total, #{Patient.where(state: 'candidate').count} candidates)"
    puts "== done =="
  end

  desc "Remove ONLY the rows demo:review_data created (CONFIRM=yes)"
  task purge: :environment do
    abort "Refusing to run without CONFIRM=yes." unless ENV["CONFIRM"] == "yes"

    patients = Patient.where("participant_code LIKE ?", "#{DEMO_CODE_PREFIX}%")
    studies  = Study.where("public_title LIKE ?", "#{DEMO_TITLE_PREFIX}%")
    sponsors = Sponsor.where("name LIKE ?", "#{DEMO_TITLE_PREFIX}%")

    puts "Destroying #{patients.count} demo patients, #{studies.count} demo studies, #{sponsors.count} demo sponsors."
    patients.destroy_all
    studies.each { |s| s.criteria_profile&.destroy }
    studies.destroy_all
    sponsors.destroy_all
    puts "Real records were never matched by these patterns and are untouched."
  end

  # Demo patients carry a DEMO- participant_code on purpose: it is plaintext (so
  # it can be queried and purged), and `display_name` falls back to it for a
  # lead, so anyone looking at the recruitment list sees "DEMO-…" and cannot
  # mistake the row for a real person who needs calling.
  def demo_patient!(study, state:, lead: false)
    traits = lead ? [ :patient, :lead ] : [ :patient ]
    FactoryBot.create(*traits, study: study, state: state,
                      participant_code: "#{DEMO_CODE_PREFIX}#{SecureRandom.alphanumeric(6).upcase}",
                      reported_city: Patient::PRINCIPAL_CITIES.sample)
  end
end
