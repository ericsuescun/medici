# == Schema Information
#
# Table name: cities
#
#  id         :bigint           not null, primary key
#  name       :string           default("")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :city do
    name { Faker::Nation.unique.capital_city }
  end
end
