# == Schema Information
#
# Table name: local_parameters
#
#  id           :bigint           not null, primary key
#  description  :string
#  display_name :string
#  name         :string           not null
#  value        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  country_id   :bigint           not null
#
# Indexes
#
#  index_local_parameters_on_country_id           (country_id)
#  index_local_parameters_on_country_id_and_name  (country_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#
FactoryBot.define do
  factory :local_parameter do
    association :country
    sequence(:name) { |n| "parameter_#{n}" }
    value { "VALOR" }
    display_name { nil }
    description { nil }

    # The one parameter the study form reads: what the local regulator is called.
    trait :health_authority do
      association :country, :colombia
      name { LocalParameter::LOCAL_HEALTH_AUTHORITY }
      value { "INVIMA" }
      display_name { "INVIMA" }
      description { "Instituto Nacional de Vigilancia de Medicamentos y Alimentos" }
    end
  end
end
