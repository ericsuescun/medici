puts 'Creating ID Types...'

colombia_id_types = [
  { name: 'Cédula de Ciudadanía', code: 'CC', description: 'Documento de identidad para ciudadanos colombianos.' },
  { name: 'Tarjeta de Identidad', code: 'TI', description: 'Documento de identidad para menores de edad.' },
  { name: 'Cédula de Extranjería', code: 'CE', description: 'Documento de identidad para extranjeros residentes.' },
  { name: 'Número de Identificación Tributaria', code: 'NIT', description: 'Identificación tributaria para personas jurídicas y algunas naturales.' },
  { name: 'Pasaporte', code: 'PAS', description: 'Documento de viaje internacional.' },
  { name: 'Registro Civil de Nacimiento', code: 'RC', description: 'Documento de identidad para recién nacidos y menores no titulares de TI.' },
  { name: 'Número Único de Identificación Personal', code: 'NUIP', description: 'Identificador único asignado por la Registraduría.' },
  { name: 'Permiso por Protección Temporal', code: 'PPT', description: 'Documento para migrantes venezolanos bajo Estatuto Temporal de Protección.' },
  { name: 'Permiso Especial de Permanencia', code: 'PEP', description: 'Documento para migrantes con permanencia especial (anterior al PPT).' },
  { name: 'Salvoconducto de Permanencia', code: 'SD', description: 'Documento temporal de permanencia emitido por Migración Colombia.' },
  { name: 'Tarjeta de Movilidad Fronteriza', code: 'TM', description: 'Documento para tránsito fronterizo de nacionales de países vecinos.' }
]

colombia_id_types.each do |attrs|
  IdType.find_or_create_by!(country_code: 'CO', code: attrs[:code]) do |it|
    it.name = attrs[:name]
    it.description = attrs[:description]
    it.active = true
  end
end

puts 'ID Types done...'
