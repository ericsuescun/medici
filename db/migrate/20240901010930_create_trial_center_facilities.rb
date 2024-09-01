class CreateTrialCenterFacilities < ActiveRecord::Migration[7.2]
  def change
    create_table :trial_center_facilities do |t|
      t.string :name
      t.string :initials
      t.string :email
      t.string :description
      t.string :contact_number
      t.string :contact_address
      t.string :url

      t.timestamps
    end
  end
end
