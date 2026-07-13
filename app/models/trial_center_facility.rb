# == Schema Information
#
# Table name: trial_center_facilities
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  description     :string
#  email           :string
#  initials        :string
#  name            :string
#  url             :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class TrialCenterFacility < ApplicationRecord
  has_and_belongs_to_many :cities
  has_and_belongs_to_many :studies

  has_many :trial_center_branches
end
