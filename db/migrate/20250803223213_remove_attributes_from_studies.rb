class RemoveAttributesFromStudies < ActiveRecord::Migration[8.0]
  def change
    remove_column :studies, :control_group, :string
    remove_column :studies, :participant_ending_age, :integer
    remove_column :studies, :participant_starting_age, :integer
    remove_column :studies, :medical_preexistence, :string
    remove_column :studies, :ethical_committee, :string
    remove_column :studies, :ethical_approval_at, :date
    remove_column :studies, :keywords, :string
    remove_column :studies, :medication, :string
    remove_column :studies, :pathology, :string
  end
end
