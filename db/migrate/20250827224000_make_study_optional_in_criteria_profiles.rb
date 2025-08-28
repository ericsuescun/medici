class MakeStudyOptionalInCriteriaProfiles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :criteria_profiles, :study_id, true
  end
end