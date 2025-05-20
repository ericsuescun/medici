# == Schema Information
#
# Table name: trial_center_branches
#
#  id                       :bigint           not null, primary key
#  address                  :string           default("")
#  description              :string           default("")
#  initials                 :string           default("")
#  name                     :string           default(""), not null
#  phone_number             :string           default("")
#  url                      :string           default("")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  trial_center_facility_id :bigint           not null
#
# Indexes
#
#  index_trial_center_branches_on_trial_center_facility_id  (trial_center_facility_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_facility_id => trial_center_facilities.id)
#
require 'rails_helper'

RSpec.describe TrialCenterBranch, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
