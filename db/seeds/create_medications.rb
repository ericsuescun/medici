puts 'Creating Medications...'
medications = [
  { name: 'Acetaminophen', description: 'Pain reliever and fever reducer' },
  { name: 'Ibuprofen', description: 'Nonsteroidal anti-inflammatory drug (NSAID)' },
  { name: 'Aspirin', description: 'Pain reliever, anti-inflammatory, and blood thinner' },
  { name: 'Amoxicillin', description: 'Antibiotic used to treat bacterial infections' },
  { name: 'Lisinopril', description: 'ACE inhibitor used to treat high blood pressure' },
  { name: 'Metformin', description: 'Used to treat type 2 diabetes' },
  { name: 'Atorvastatin', description: 'Statin used to lower cholesterol' },
  { name: 'Levothyroxine', description: 'Thyroid hormone replacement' },
  { name: 'Omeprazole', description: 'Proton pump inhibitor used to reduce stomach acid' },
  { name: 'Losartan', description: 'Angiotensin II receptor blocker used to treat high blood pressure' },
  { name: 'Albuterol', description: 'Bronchodilator used to treat asthma' },
  { name: 'Gabapentin', description: 'Anticonvulsant and nerve pain medication' },
  { name: 'Sertraline', description: 'Selective serotonin reuptake inhibitor (SSRI) antidepressant' },
  { name: 'Fluoxetine', description: 'SSRI antidepressant' },
  { name: 'Metoprolol', description: 'Beta-blocker used to treat high blood pressure and heart conditions' }
]

medications.each do |med_attrs|
  Medication.find_or_create_by!(name: med_attrs[:name]) do |medication|
    medication.description = med_attrs[:description]
    puts "Created medication: #{medication.name}"
  end
end

puts 'Associating medications with studies...'
Study.all.each do |study|
  # Skip if the study already has medications
  next if study.medications.any?

  # Associate 1-3 random medications with each study
  medication_count = rand(1..3)
  random_medications = Medication.all.sample(medication_count)

  study.medications << random_medications
  puts "Associated #{medication_count} medications with study: #{study.short_title}"
end

puts 'Medications done...'
