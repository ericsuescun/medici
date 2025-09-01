# == Schema Information
#
# Table name: id_types
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  code         :string           not null
#  country_code :string           not null
#  description  :string
#  active       :boolean          default(TRUE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class IdType < ApplicationRecord
  # ISO 3166-1 alpha-2 country code expected in country_code (e.g., 'CO')
  validates :name, presence: true
  validates :code, presence: true
  validates :country_code, presence: true, length: { is: 2 }

  validates :code, uniqueness: { scope: :country_code, case_sensitive: false }

  scope :by_country, ->(cc) { where(country_code: cc.to_s.upcase) }
  scope :active, -> { where(active: true) }
end
