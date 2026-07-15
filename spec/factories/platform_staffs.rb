# == Schema Information
#
# Table name: platform_staffs
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :platform_staff do
    contact_number { "3001234567" }
    contact_address { "Cra 1 # 2-3" }
    title { "Community Manager" }
  end
end
