class CreatePlatformStaffs < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_staffs do |t|
      t.string :contact_number
      t.string :contact_address
      t.string :title

      t.timestamps
    end
  end
end
