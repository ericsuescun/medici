class UpdatePatientsRemoveUserAndAddFields < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:patients, :user_id)
      remove_reference :patients, :user, foreign_key: true
    end

    add_column :patients, :illness_description, :text, default: ""
    add_column :patients, :id_type, :string, default: ""
    add_column :patients, :id_number, :string, default: ""
  end
end
