# == Schema Information
#
# Table name: trial_center_branch_reps
#
#  id                     :bigint           not null, primary key
#  contact_address        :string
#  contact_number         :string
#  title                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  trial_center_branch_id :bigint
#
# Indexes
#
#  index_trial_center_branch_reps_on_trial_center_branch_id  (trial_center_branch_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_branch_id => trial_center_branches.id)
#
FactoryBot.define do
  factory :trial_center_branch_rep do
    association :trial_center_branch
    contact_number { "MyString" }
    contact_address { "MyString" }
    title { "MyString" }
  end
end
