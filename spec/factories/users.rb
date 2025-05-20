# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  contact_address        :string           default("")
#  contact_number         :string           default("")
#  dob                    :date
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  firstname              :string           default("")
#  id_number              :string           default("")
#  id_type                :string           default("")
#  lastname               :string           default("")
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  user_type              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
FactoryBot.define do
  factory :user do
    contact_address { Faker::Address.street_address }
    contact_number { Faker::PhoneNumber.phone_number }
    dob { Faker::Date.birthday(min_age: 18, max_age: 65) }
    sequence(:email) { |n| Faker::Lorem.word + n.to_s + '@yopmail.com' }
    password { '12345678' }
    password_confirmation { '12345678'}
    firstname { Faker::Name.first_name }
    id_number { Faker::Number.number(digits: 10) }
    id_type { 'CC' }
    lastname { Faker::Name.last_name }
    remember_created_at { Faker::Date.backward(days: 14) }
    reset_password_sent_at { nil }
    reset_password_token { nil }
    user_type { %w[sponsor admin patient].sample }
  end
end
