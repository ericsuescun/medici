class RemoveStudyTypeFromStudies < ActiveRecord::Migration[8.0]
  def change
    remove_column :studies, :study_type, :string
  end
end
