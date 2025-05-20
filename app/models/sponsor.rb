# == Schema Information
#
# Table name: sponsors
#
#  id           :bigint           not null, primary key
#  initials     :string
#  name         :string
#  shortname    :string
#  sponsor_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Sponsor < ApplicationRecord
  enum :sponsor_type, private_type: 'private_type', public_type: 'public_type', mixed_type: 'mixed_type'

  has_many :studies, dependent: :destroy

  def capitals
    initials = name.scan /\p{Upper}/
    initials.join
  end
end
