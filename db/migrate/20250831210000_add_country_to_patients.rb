class AddCountryToPatients < ActiveRecord::Migration[8.0]
  def change
    add_column :patients, :country, :string, default: ""
  end
end