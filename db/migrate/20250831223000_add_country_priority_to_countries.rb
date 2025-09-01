class AddCountryPriorityToCountries < ActiveRecord::Migration[8.0]
  def change
    add_column :countries, :country_priority, :integer, default: 4, null: false
    add_index :countries, :country_priority
  end
end