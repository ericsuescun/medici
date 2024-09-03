# == Schema Information
#
# Table name: trial_cities
#
#  id         :bigint           not null, primary key
#  name       :string           default("")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  study_id   :bigint           not null
#
# Indexes
#
#  index_trial_cities_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
require "test_helper"

class TrialCityTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
