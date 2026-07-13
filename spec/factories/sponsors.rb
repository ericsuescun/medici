# == Schema Information
#
# Table name: sponsors
#
#  id           :bigint           not null, primary key
#  initials      :string
#  international  :boolean          default(FALSE), not null
#  name          :string
#  shortname     :string
#  sponsor_type  :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :sponsor do
    initials { 'ABC' }
    name { Faker::Company.name }
    shortname { 'ShortName' }
    sponsor_type { %w[private_type public_type mixed_type].sample }

    trait :international do
      international { true }
    end
  end
end
