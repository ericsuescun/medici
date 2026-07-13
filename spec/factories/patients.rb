# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :date
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  sex                 :string
#  state               :string           default("prospect"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_patients_on_state  (state)
#
FactoryBot.define do
  factory :patient do
    dob { Faker::Date.birthday(min_age: 18, max_age: 80) }
    sex { %w[male female].sample }
    # state defaults to "prospect" (DB default); AASM manages transitions.
  end
end
