# == Schema Information
#
# Table name: countries
#
#  id               :bigint           not null, primary key
#  code             :string           not null
#  country_priority :integer          default(4), not null
#  name             :string           not null
#  phone_prefix     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_countries_on_code              (code) UNIQUE
#  index_countries_on_country_priority  (country_priority)
#
class Country < ApplicationRecord
  # ISO 3166-1 alpha-2 recommended for code (e.g., 'CO')
  validates :name, presence: true
  validates :code, presence: true, length: { in: 2..3 }
  validates :phone_prefix, presence: true

  validates :code, uniqueness: { case_sensitive: false }

  # Basic format: + followed by digits (and optional spaces)
  validates :phone_prefix, format: { with: /\A\+\d[\d\s]*\z/, message: "must start with + and contain digits" }
end
