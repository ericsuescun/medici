# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require 'factory_bot'

# Essential authorization reference data — roles + default permission matrix.
# Idempotent and safe for every environment (creates nothing that isn't required
# for the app to function; never overwrites admin-customized permissions).
require_relative 'seeds/roles_and_permissions'
RolesAndPermissionsSeeder.seed!

# Study categories (therapeutic areas) — reference data for the study form's
# dropdown, the public home-page filter, and the navbar search.
require_relative 'seeds/categories'
CategoriesSeeder.seed!

# ---------------------------------------------------------------------------
# All sample data below is intentionally DISABLED (commented out).
#
# `bin/rails db:seed` (and `db:setup`) run automatically in every environment,
# so leaving these active is a source of issues — the sample blocks generate
# fake users (with hard-coded passwords) and a large FactoryBot data graph that
# must never land in production. Enable a block deliberately, in development
# only, when you need sample data. The code is kept correct for the current
# models (delegated_type users, reps required to belong to a parent).
# ---------------------------------------------------------------------------

# Reference / lookup data:
# require_relative 'seeds/update_studies_short_title'
# require_relative 'seeds/create_medications'
# require_relative 'seeds/create_id_types'
# require_relative 'seeds/create_countries'
#
# Example eligibility profile (dev/demo only — see the file header):
# require_relative 'seeds/example_seborrheic_dermatitis_profile'
# ExampleSeborrheicDermatitisProfile.seed!
#
# Named admin accounts:
# [ [ 'edsuescun@gmail.com', 'Eric', 'Suescun' ],
#   [ 'nlecuona@gmail.com', 'Nathalia', 'Lecuona' ],
#   [ 'agiraldo@gmail.com', 'Alejandro', 'Giraldo' ]
# ].each do |email, first, last|
#   next if User.exists?(email: email)
#
#   FactoryBot.create(:user, :admin,
#                     email: email,
#                     password: '12345678',
#                     password_confirmation: '12345678',
#                     firstname: first,
#                     lastname: last)
# end
#
# Sample patients:
# 50.times { FactoryBot.create(:user, :patient) }
#
# A few extra admins:
# 5.times { FactoryBot.create(:user, :admin) }
#
# Sample facilities + branches, each with its own representatives
# (reps must belong to a branch):
# FactoryBot.create_list(:trial_center_facility, 30) do |tcf|
#   tcf.cities << FactoryBot.create(:city)
#   FactoryBot.create_list(:trial_center_branch, (1..3).to_a.sample, trial_center_facility: tcf) do |tcb|
#     tcb.cities << FactoryBot.create(:city)
#     (1..2).to_a.sample.times do
#       FactoryBot.create(:user, userable: FactoryBot.build(:trial_center_branch_rep, trial_center_branch: tcb))
#     end
#   end
# end
#
# Sample sponsors, each with its own representatives (reps must belong to a
# sponsor) plus a studies graph:
# FactoryBot.create_list(:sponsor, 20) do |sponsor|
#   (1..3).to_a.sample.times do
#     FactoryBot.create(:user, userable: FactoryBot.build(:sponsor_rep, sponsor: sponsor))
#   end
#   FactoryBot.create_list(:study, (1..5).to_a.sample, sponsor: sponsor) do |study|
#     study.trial_center_branches << TrialCenterBranch.find(TrialCenterBranch.ids.sample((1..3).to_a.sample))
#     # Every study belongs to 1..3 therapeutic areas (the seeded Category list).
#     study.categories << Category.order("RANDOM()").limit(rand(1..3))
#     # Mostly recruiting, a few completed (completed reads as "disabled"), with
#     # a small recruitment goal so the progress bar shows meaningful fill...
#     study.update!(study_status: rand < 0.8 ? "recruiting" : "completed",
#                   sample_size: rand(8..20))
#     # ...and patients spread across the lifecycle states that fill it:
#     # participants (green), candidates (yellow), prospects (red).
#     rand(1..4).times { FactoryBot.create(:patient, :participant, study: study) }
#     rand(0..4).times { FactoryBot.create(:patient, :candidate, study: study) }
#     rand(0..5).times { FactoryBot.create(:patient, study: study) }
#     FactoryBot.create_list(:article, (1..3).to_a.sample, study: study)
#     FactoryBot.create_list(:contact, (1..2).to_a.sample, study: study)
#     FactoryBot.create_list(:result, (1..4).to_a.sample, study: study)
#   end
# end
#
# Enroll each sample patient in a random study:
# User.patients.each { |user| user.studies << Study.find(Study.ids.sample) }
