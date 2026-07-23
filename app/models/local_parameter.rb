# == Schema Information
#
# Table name: local_parameters
#
#  id           :bigint           not null, primary key
#  description  :string
#  display_name :string
#  name         :string           not null
#  value        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  country_id   :bigint           not null
#
# Indexes
#
#  index_local_parameters_on_country_id           (country_id)
#  index_local_parameters_on_country_id_and_name  (country_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#
# Country-specific configuration, admin-managed (see LocalParametersController,
# which is admin-only and deliberately outside the Role permission matrix).
#
# Each row is one named parameter for one country, so the same `name` can hold a
# different value per jurisdiction: `local_health_authority` is "INVIMA" in
# Colombia, "ANMAT" in Argentina. Views must render `label` (the human name),
# never the `name` key.
class LocalParameter < ApplicationRecord
  # Changing what the platform tells staff a regulator is called is worth an
  # audit entry.
  has_paper_trail

  # The regulator that authorises interventional research — the study form asks
  # "¿Aprobado por INVIMA?" by resolving this.
  LOCAL_HEALTH_AUTHORITY = "local_health_authority".freeze

  # The platform is Colombia-first; a study carries no country of its own (no
  # facility/branch does either), so lookups fall back to this jurisdiction.
  DEFAULT_COUNTRY_CODE = "CO".freeze

  belongs_to :country

  validates :name, presence: true, uniqueness: { scope: :country_id, case_sensitive: false }
  validates :value, presence: true

  scope :for_country, ->(country) { where(country: country) }

  # What to show a user: the display name if one was given, else the raw value.
  def label
    display_name.presence || value
  end

  # The parameter `name` for `country` (defaults to Colombia). Returns nil when
  # it has not been configured — callers decide the fallback wording rather than
  # being handed a cryptic key.
  def self.find_parameter(name, country: nil)
    country ||= Country.find_by(code: DEFAULT_COUNTRY_CODE)
    return nil if country.nil?

    find_by(country: country, name: name)
  end

  # Convenience for the study form: "INVIMA", or nil if unconfigured.
  def self.health_authority_label(country: nil)
    find_parameter(LOCAL_HEALTH_AUTHORITY, country: country)&.label
  end
end
