class AddShortTitleToStudies < ActiveRecord::Migration[8.0]
  def change
    add_column :studies, :short_title, :string, default: ""
  end
end
