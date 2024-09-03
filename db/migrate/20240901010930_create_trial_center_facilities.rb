class CreateTrialCenterFacilities < ActiveRecord::Migration[7.2]
  def change
    create_table :trial_center_facilities do |t|
      t.string :name, default: ""
      t.string :initials, default: ""
      t.string :email, default: ""
      t.string :description, default: ""
      t.string :contact_number, default: ""
      t.string :contact_address, default: ""
      t.string :url, default: ""

      t.timestamps
    end
  end
end
