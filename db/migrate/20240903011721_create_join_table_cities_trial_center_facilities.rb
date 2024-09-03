class CreateJoinTableCitiesTrialCenterFacilities < ActiveRecord::Migration[7.2]
  def change
    create_join_table :cities, :trial_center_facilities do |t|
      t.index [:city_id, :trial_center_facility_id]
      t.index [:trial_center_facility_id, :city_id]
    end
  end
end
