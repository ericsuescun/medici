# == Schema Information
#
# Table name: trial_center_facilities
#
#  id              :bigint           not null, primary key
#  contact_address :string           default("")
#  contact_number  :string           default("")
#  description     :string           default("")
#  email           :string           default("")
#  initials        :string           default("")
#  name            :string           default("")
#  url             :string           default("")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class TrialCenterFacility < ApplicationRecord
  has_and_belongs_to_many :cities
  has_and_belongs_to_many :studies
end
