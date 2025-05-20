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

puts 'Creating Users...'
50.times do
  FactoryBot.create(:user)
end
puts 'Users done...\n'

puts 'Creating Facilities...'
FactoryBot.create_list(:trial_center_facility, 30) do |tcf|
  tcf.cities << FactoryBot.create(:city)
  FactoryBot.create_list(:trial_center_branch, (1..3).to_a.sample, trial_center_facility: tcf) do |tcb|
    tcb.cities << FactoryBot.create(:city)
  end
end
puts 'Facilities done...\n'

puts 'Creating Sponsors...'
FactoryBot.create_list(:sponsor, 20) do |sponsor|
  FactoryBot.create_list(:study, (1..5).to_a.sample, sponsor: sponsor) do |study|
    puts 'Creating Studies...'
    study.users << User.find(User.patients.ids.sample((1..3).to_a.sample))
    study.trial_center_branches << TrialCenterBranch.find(TrialCenterBranch.ids.sample((1..3).to_a.sample))

    puts 'Creating Articles...'
    FactoryBot.create_list(:article, (1..3).to_a.sample, study: study)
    puts 'Creating Contacts...'
    FactoryBot.create_list(:contact, (1..2).to_a.sample, study: study)
    puts 'Creating Results...'
    FactoryBot.create_list(:result, (1..4).to_a.sample, study: study)
  end
end