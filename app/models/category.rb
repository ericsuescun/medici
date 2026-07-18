# A therapeutic area a study belongs to (Cardiología, Dermatología, …).
# Reference data seeded by CategoriesSeeder (db/seeds/categories.rb); staff
# attach 1..n to each study from the study form. Powers the public home-page
# filter pills and the navbar search's category results.
# == Schema Information
#
# Table name: categories
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_categories_on_name  (name) UNIQUE
#
class Category < ApplicationRecord
  has_and_belongs_to_many :studies

  validates :name, presence: true, uniqueness: true

  # Only categories that would produce a non-empty home-page filter.
  scope :in_use, -> { joins(:studies).distinct.order(:name) }
end
