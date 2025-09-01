# Custom seed tasks for selective seeding
# Usage:
#   bin/rails seeds:countries
#   bin/rails seeds:id_types
#   bin/rails seeds:all

namespace :seeds do
  desc 'Seed countries from db/seeds/create_countries.rb'
  task countries: :environment do
    seed_file = Rails.root.join('db', 'seeds', 'create_countries.rb')
    puts "Loading #{seed_file}..."
    load seed_file
  end

  desc 'Seed id_types from db/seeds/create_id_types.rb'
  task id_types: :environment do
    seed_file = Rails.root.join('db', 'seeds', 'create_id_types.rb')
    if File.exist?(seed_file)
      puts "Loading #{seed_file}..."
      load seed_file
    else
      abort "Seed file not found: #{seed_file}"
    end
  end

  desc 'Run all custom seeds (countries, id_types)'
  task all: :environment do
    Rake::Task['seeds:countries'].invoke
    # Reenable so tasks can be called again in same process if needed
    Rake::Task['seeds:countries'].reenable

    if Rake::Task.task_defined?('seeds:id_types')
      Rake::Task['seeds:id_types'].invoke
    end
  end
end
