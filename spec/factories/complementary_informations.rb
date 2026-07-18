# == Schema Information
#
# Table name: complementary_informations
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  patient_id :bigint           not null
#
# Indexes
#
#  index_complementary_informations_on_patient_id  (patient_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
FactoryBot.define do
  factory :complementary_information do
    association :patient
    notes { "Previous MRI at another clinic; results attached." }
  end
end
