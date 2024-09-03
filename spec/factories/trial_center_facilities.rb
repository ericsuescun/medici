# == Schema Information
#
# Table name: trial_center_facilities
#
#  id              :bigint           not null, primary key
#  contact_address :string           default("")
#  contact_number  :string           default("")
#  description     :string           default("")
#  email           :string           default("")
#  initials        :string           default("")
#  name            :string           default("")
#  url             :string           default("")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :trial_center_facility do
    contact_address { Faker::Address.street_address }
    contact_number { Faker::PhoneNumber.phone_number }
    description { Faker::Lorem.paragraph }
    email { Faker::Internet.email }
    initials { 'ABC' }
    name { Faker::Company.name }
    url { Faker::Internet.url }
  end
end
