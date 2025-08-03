puts "Updating existing studies with short_title values..."

Study.where(short_title: "").each do |study|
  # Generate a short title based on the first few words of the public_title
  # or use a random set of words if public_title is empty
  if study.public_title.present?
    words = study.public_title.split(' ')
    short_title = words.take([3, words.length].min).join(' ')
  else
    short_title = Faker::Lorem.words(number: 3).join(' ')
  end
  
  study.update(short_title: short_title)
  puts "Updated study ID #{study.id} with short_title: #{short_title}"
end

puts "Finished updating #{Study.count} studies with short_title values."