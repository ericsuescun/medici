class UpdateStudiesColumns < ActiveRecord::Migration[8.0]
  def change
    # Rename approved_at to completed_at
    rename_column :studies, :approved_at, :completed_at
    
    # Remove local_unique_register and registered_at columns
    remove_column :studies, :local_unique_register
    remove_column :studies, :registered_at
  end
end
