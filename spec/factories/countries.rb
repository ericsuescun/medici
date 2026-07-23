# == Schema Information
#
# Table name: countries
#
#  id               :bigint           not null, primary key
#  code             :string           not null
#  country_priority :integer          default(4), not null
#  name             :string           not null
#  phone_prefix     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_countries_on_code              (code) UNIQUE
#  index_countries_on_country_priority  (country_priority)
#
FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "País #{n}" }
    sequence(:code) { |n| ("AA".."ZZ").to_a[n % 676] }
    phone_prefix { "+57" }

    trait :colombia do
      name { "Colombia" }
      code { LocalParameter::DEFAULT_COUNTRY_CODE }
      phone_prefix { "+57" }
    end
  end
end
