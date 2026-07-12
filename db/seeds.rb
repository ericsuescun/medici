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

# ---------------------------------------------------------------------------
# All seed data below is intentionally DISABLED (commented out).
#
# `bin/rails db:seed` (and `db:setup`) run automatically in every environment,
# so leaving these active is a source of issues — the sample blocks generate
# fake users (with hard-coded passwords) and a large FactoryBot data graph that
# must never land in production. Enable a block deliberately, in development
# only, when you need sample data.
#
# The code is kept correct for the current delegated_type user model (role
# traits), so it works as-is if you uncomment it.
# ---------------------------------------------------------------------------

# Reference / lookup data (uncomment the pieces your local work needs):
# require_relative 'seeds/update_studies_short_title'
# require_relative 'seeds/create_medications'
# require_relative 'seeds/create_id_types'
# require_relative 'seeds/create_countries'

# Named admin accounts:
# [ ['edsuescun@gmail.com', 'Eric', 'Suescun'],
#   ['nlecuona@gmail.com', 'Nathalia', 'Lecuona'],
#   ['agiraldo@gmail.com', 'Alejandro', 'Giraldo']
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

# Sample users:
# puts 'Creating Users...'
# 50.times do
#   FactoryBot.create(:user, :patient)
# end
#
# 10.times do
#   FactoryBot.create(:user, %i[admin sponsor_rep trial_center_branch_rep].sample)
# end
# puts 'Users done...'

# Sample facilities / sponsors / studies graph:
# puts 'Creating Facilities...'
# FactoryBot.create_list(:trial_center_facility, 30) do |tcf|
#   tcf.cities << FactoryBot.create(:city)
#   FactoryBot.create_list(:trial_center_branch, (1..3).to_a.sample, trial_center_facility: tcf) do |tcb|
#     tcb.cities << FactoryBot.create(:city)
#   end
# end
# puts 'Facilities done...'
#
# puts 'Creating Sponsors...'
# FactoryBot.create_list(:sponsor, 20) do |sponsor|
#   FactoryBot.create_list(:study, (1..5).to_a.sample, sponsor: sponsor) do |study|
#     puts 'Creating Studies...'
#     study.trial_center_branches << TrialCenterBranch.find(TrialCenterBranch.ids.sample((1..3).to_a.sample))
#     puts 'Creating Articles...'
#     FactoryBot.create_list(:article, (1..3).to_a.sample, study: study)
#     puts 'Creating Contacts...'
#     FactoryBot.create_list(:contact, (1..2).to_a.sample, study: study)
#     puts 'Creating Results...'
#     FactoryBot.create_list(:result, (1..4).to_a.sample, study: study)
#   end
# end
#
# User.patients.each do |user|
#   user.studies << Study.find(Study.ids.sample)
# end
