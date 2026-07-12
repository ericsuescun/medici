class AddStateToPatients < ActiveRecord::Migration[8.0]
  def change
    add_column :patients, :state, :string, null: false, default: 'prospect'
    add_index :patients, :state
  end
end
