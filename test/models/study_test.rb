# == Schema Information
#
# Table name: studies
#
#  id                       :bigint           not null, primary key
#  approved_at              :date
#  control_group            :string           default("")
#  ethical_approval_at      :date
#  ethical_committee        :string           default("")
#  exclusion_criteria       :string           default("")
#  first_patient_at         :date
#  global_ending_at         :date
#  inclusion_criteria       :string           default("")
#  keywords                 :string           default("")
#  local_unique_register    :string           default("")
#  main_intervention        :string           default("")
#  medical_preexistences    :string           default("")
#  medication               :string           default("")
#  participant_ending_age   :integer
#  participant_starting_age :integer
#  pathology                :string           default("")
#  public_title             :string           default("")
#  registered_at            :date
#  reviewed                 :boolean          default(FALSE)
#  sample_size              :integer
#  scientific_title         :string           default("")
#  sex                      :string           default("")
#  started_at               :date
#  study_phase              :string
#  study_status             :string
#  study_type               :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  review_user_id           :integer
#  sponsor_id               :bigint           not null
#
# Indexes
#
#  index_studies_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  fk_rails_...  (sponsor_id => sponsors.id)
#
require "test_helper"

class StudyTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
