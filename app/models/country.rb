# == Schema Information
#
# Table name: countries
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  code         :string           not null
#  phone_prefix :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Country < ApplicationRecord
  # ISO 3166-1 alpha-2 recommended for code (e.g., 'CO')
  validates :name, presence: true
  validates :code, presence: true, length: { in: 2..3 }
  validates :phone_prefix, presence: true

  validates :code, uniqueness: { case_sensitive: false }

  # Basic format: + followed by digits (and optional spaces)
  validates :phone_prefix, format: { with: /\A\+\d[\d\s]*\z/, message: 'must start with + and contain digits' }
end
