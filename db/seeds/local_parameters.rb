# Idempotent seeder for country-specific configuration (see LocalParameter).
# Reference data required by the study form, which asks an interventional study
# whether the LOCAL health authority approved it and must name that authority —
# "INVIMA" in Colombia, not a cryptic `local_health_authority` key.
#
# Safe for every environment, like RolesAndPermissionsSeeder: it never
# overwrites a value an admin has edited, it only creates what is missing.
module LocalParametersSeeder
  # Colombia is the platform's home jurisdiction. The countries table is seeded
  # separately (and that seeder is disabled by default), so create it here if
  # it is missing rather than silently skipping the parameter.
  COLOMBIA = { code: "CO", name: "Colombia", phone_prefix: "+57" }.freeze

  PARAMETERS = [
    {
      country_code: "CO",
      name: LocalParameter::LOCAL_HEALTH_AUTHORITY,
      value: "INVIMA",
      display_name: "INVIMA",
      description: "Instituto Nacional de Vigilancia de Medicamentos y Alimentos"
    }
  ].freeze

  def self.seed!
    colombia = Country.find_by(code: COLOMBIA[:code]) ||
               Country.create!(**COLOMBIA)

    PARAMETERS.each do |attrs|
      country = attrs[:country_code] == COLOMBIA[:code] ? colombia : Country.find_by(code: attrs[:country_code])
      next if country.nil?

      LocalParameter.find_or_create_by!(country: country, name: attrs[:name]) do |parameter|
        parameter.value = attrs[:value]
        parameter.display_name = attrs[:display_name]
        parameter.description = attrs[:description]
      end
    end
  end
end
