namespace :users do
  desc "Create missing userable records for existing users"
  task create_userable_records: :environment do
    puts "Creating missing userable records..."

    # Map user_type to delegated class
    type_mapping = {
      "admin" => "Admin",
      "sponsor" => "SponsorRep",
      "patient" => "Patient"
    }

    User.where(userable: nil).find_each do |user|
      # Determine type from either legacy user_type or existing userable_type inference
      legacy_type = user.respond_to?(:user_type) ? user.user_type : nil
      inferred_type = legacy_type || (user.userable_type.present? ? user.userable_type.underscore : nil)
      next if inferred_type.blank?

      userable_type = type_mapping[legacy_type] || user.userable_type

      case userable_type
      when "Admin"
        new_record = userable_type.constantize.create!(contact_number: user.contact_number, contact_address: user.contact_address)
        user.update!(userable: new_record)
      when "SponsorRep"
        new_record = userable_type.constantize.create!(contact_number: user.contact_number, contact_address: user.contact_address)
        user.update!(userable: new_record)
      when "Patient"
        new_record = userable_type
                       .constantize
                       .create!(contact_number: user.contact_number,
                                contact_address: user.contact_address,
                                id_number: user.id_number,
                                id_type: user.id_type,
                                illness_description: user.illness_description)
        user.update!(userable: new_record)
      end
    end

    puts "Finished creating userable records"
  end
end
