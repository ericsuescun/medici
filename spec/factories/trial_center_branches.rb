# == Schema Information
#
# Table name: trial_center_branches
#
#  id                       :bigint           not null, primary key
#  address                  :string           default("")
#  description              :string           default("")
#  initials                 :string           default("")
#  name                     :string           default(""), not null
#  phone_number             :string           default("")
#  url                      :string           default("")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  trial_center_facility_id :bigint           not null
#
# Indexes
#
#  index_trial_center_branches_on_trial_center_facility_id  (trial_center_facility_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_facility_id => trial_center_facilities.id)
#
FactoryBot.define do
  factory :trial_center_branch do
    association :trial_center_facility, factory: :trial_center_facility

    contact_address { Faker::Address.street_address }
    contact_number { Faker::PhoneNumber.phone_number }
    description { Faker::Lorem.paragraph }
    email { Faker::Internet.email }
    initials { 'XYZ' }
    name { Faker::Company.name }
    url { Faker::Internet.url }
  end
end
