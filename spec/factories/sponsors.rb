# == Schema Information
#
# Table name: sponsors
#
#  id           :bigint           not null, primary key
#  initials     :string
#  name         :string
#  shortname    :string
#  sponsor_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :sponsor, class: "Sponsor" do
    initials { 'ABC' }
    name { Faker::Company.name }
    shortname { 'ShortName'}
    sponsor_type { %w[private_type public_type mixed_type].sample }
  end
end
