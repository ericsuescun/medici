# == Schema Information
#
# Table name: medications
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Medication < ApplicationRecord
  has_and_belongs_to_many :studies

  validates :name, presence: true, uniqueness: true

  default_scope { order(name: :asc) }
end
