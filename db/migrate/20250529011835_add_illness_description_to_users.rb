class AddIllnessDescriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :illness_description, :string, default: ""
  end
end
