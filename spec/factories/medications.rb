# == Schema Information
#
# Table name: medications
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :medication do
    sequence(:name) { |n| "Medication #{n}" }
    description { Faker::Lorem.paragraph }
  end
end
