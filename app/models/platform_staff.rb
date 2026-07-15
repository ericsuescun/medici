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
class PlatformStaff < ApplicationRecord
  include Userable
  include DelegatesIdentityToUser
end
