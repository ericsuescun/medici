class Medication < ApplicationRecord
  has_and_belongs_to_many :studies

  validates :name, presence: true, uniqueness: true

  default_scope { order(name: :asc) }
end
