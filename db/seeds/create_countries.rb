puts 'Creating Countries...'

# Countries of the Americas (North, Central, South America and the Caribbean)
# ISO 3166-1 alpha-2 codes with common phone calling codes
countries = [
  # North America
  { name: 'United States', code: 'US', phone_prefix: '+1' },
  { name: 'Canada', code: 'CA', phone_prefix: '+1' },
  { name: 'Mexico', code: 'MX', phone_prefix: '+52' },

  # Central America
  { name: 'Belize', code: 'BZ', phone_prefix: '+501' },
  { name: 'Costa Rica', code: 'CR', phone_prefix: '+506' },
  { name: 'El Salvador', code: 'SV', phone_prefix: '+503' },
  { name: 'Guatemala', code: 'GT', phone_prefix: '+502' },
  { name: 'Honduras', code: 'HN', phone_prefix: '+504' },
  { name: 'Nicaragua', code: 'NI', phone_prefix: '+505' },
  { name: 'Panama', code: 'PA', phone_prefix: '+507' },

  # Caribbean (sovereign states)
  { name: 'Antigua and Barbuda', code: 'AG', phone_prefix: '+1 268' },
  { name: 'Bahamas', code: 'BS', phone_prefix: '+1 242' },
  { name: 'Barbados', code: 'BB', phone_prefix: '+1 246' },
  { name: 'Cuba', code: 'CU', phone_prefix: '+53' },
  { name: 'Dominica', code: 'DM', phone_prefix: '+1 767' },
  { name: 'Dominican Republic', code: 'DO', phone_prefix: '+1 809' },
  { name: 'Grenada', code: 'GD', phone_prefix: '+1 473' },
  { name: 'Haiti', code: 'HT', phone_prefix: '+509' },
  { name: 'Jamaica', code: 'JM', phone_prefix: '+1 876' },
  { name: 'Saint Kitts and Nevis', code: 'KN', phone_prefix: '+1 869' },
  { name: 'Saint Lucia', code: 'LC', phone_prefix: '+1 758' },
  { name: 'Saint Vincent and the Grenadines', code: 'VC', phone_prefix: '+1 784' },
  { name: 'Trinidad and Tobago', code: 'TT', phone_prefix: '+1 868' },

  # South America
  { name: 'Argentina', code: 'AR', phone_prefix: '+54' },
  { name: 'Bolivia', code: 'BO', phone_prefix: '+591' },
  { name: 'Brazil', code: 'BR', phone_prefix: '+55' },
  { name: 'Chile', code: 'CL', phone_prefix: '+56' },
  { name: 'Colombia', code: 'CO', phone_prefix: '+57' },
  { name: 'Ecuador', code: 'EC', phone_prefix: '+593' },
  { name: 'Guyana', code: 'GY', phone_prefix: '+592' },
  { name: 'Paraguay', code: 'PY', phone_prefix: '+595' },
  { name: 'Peru', code: 'PE', phone_prefix: '+51' },
  { name: 'Suriname', code: 'SR', phone_prefix: '+597' },
  { name: 'Uruguay', code: 'UY', phone_prefix: '+598' },
  { name: 'Venezuela', code: 'VE', phone_prefix: '+58' },

  # Caribbean parts of the Kingdom of the Netherlands (constituent countries)
  { name: 'Aruba', code: 'AW', phone_prefix: '+297' },
  { name: 'Curaçao', code: 'CW', phone_prefix: '+599' },
  { name: 'Sint Maarten', code: 'SX', phone_prefix: '+1 721' },

  # Other American territories with ISO codes (commonly needed for phone prefixes)
  { name: 'Bermuda', code: 'BM', phone_prefix: '+1 441' },
  { name: 'Greenland', code: 'GL', phone_prefix: '+299' },
  { name: 'Guadeloupe', code: 'GP', phone_prefix: '+590' },
  { name: 'Martinique', code: 'MQ', phone_prefix: '+596' },
  { name: 'French Guiana', code: 'GF', phone_prefix: '+594' },
  { name: 'Puerto Rico', code: 'PR', phone_prefix: '+1 787' },
  { name: 'U.S. Virgin Islands', code: 'VI', phone_prefix: '+1 340' },
  { name: 'British Virgin Islands', code: 'VG', phone_prefix: '+1 284' },
  { name: 'Cayman Islands', code: 'KY', phone_prefix: '+1 345' },
  { name: 'Turks and Caicos Islands', code: 'TC', phone_prefix: '+1 649' },
  { name: 'Anguilla', code: 'AI', phone_prefix: '+1 264' },
  { name: 'Montserrat', code: 'MS', phone_prefix: '+1 664' },
  { name: 'Saint Barthélemy', code: 'BL', phone_prefix: '+590' },
  { name: 'Saint Martin', code: 'MF', phone_prefix: '+590' },
  { name: 'Sint Eustatius and Saba (Caribbean Netherlands)', code: 'BQ', phone_prefix: '+599' }
]

countries.each do |attrs|
  Country.find_or_create_by!(code: attrs[:code]) do |c|
    c.name = attrs[:name]
    c.phone_prefix = attrs[:phone_prefix]
    # Set country_priority: CO=1, VE=2, EC=3, others default 4
    case attrs[:code]
    when 'CO'
      c.country_priority = 1
    when 'VE'
      c.country_priority = 2
    when 'EC'
      c.country_priority = 3
    else
      c.country_priority = 4
    end
  end
end

puts 'Countries done...'
