class CreateJoinTableTrialCenterFacilitiesStudies < ActiveRecord::Migration[7.2]
  def change
    create_join_table :trial_center_facilities, :studies do |t|
      t.index [:trial_center_facility_id, :study_id]
      t.index [:study_id, :trial_center_facility_id]
    end
  end
end
