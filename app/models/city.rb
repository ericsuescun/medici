# == Schema Information
#
# Table name: cities
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class City < ApplicationRecord
  has_and_belongs_to_many :trial_center_facilities
  has_and_belongs_to_many :trial_center_branches
  has_and_belongs_to_many :studies
end
