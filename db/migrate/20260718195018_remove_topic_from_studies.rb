class RemoveTopicFromStudies < ActiveRecord::Migration[8.0]
  # Superseded within a day by the categories join (a study belongs to several
  # therapeutic areas, and free text fragments into differently-spelled pills).
  def change
    remove_column :studies, :topic, :string
  end
end
