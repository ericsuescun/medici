# == Schema Information
#
# Table name: admins
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :admin do
    contact_number { "MyString" }
    contact_address { "MyString" }
    title { "MyString" }
  end
end
