class AddTopicToStudies < ActiveRecord::Migration[8.0]
  def change
    add_column :studies, :topic, :string
  end
end
