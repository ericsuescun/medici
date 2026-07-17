FactoryBot.define do
  factory :complementary_information do
    association :patient
    notes { "Previous MRI at another clinic; results attached." }
  end
end
