namespace :patients do
  desc "Re-encrypt existing Patient rows at rest (run once after deploying pseudonymization)"
  task reencrypt: :environment do
    total = Patient.count
    done = 0
    Patient.find_each do |patient|
      patient.encrypt
      done += 1
      puts "  re-encrypted #{done}/#{total}" if (done % 100).zero?
    end
    puts "Done: re-encrypted #{done}/#{total} patients."
  end
end
