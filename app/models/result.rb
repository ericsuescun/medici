# == Schema Information
#
# Table name: results
#
#  id          :bigint           not null, primary key
#  description :string           default("")
#  result_type :string           default("empty")
#  title       :string           default("")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  study_id    :bigint           not null
#
# Indexes
#
#  index_results_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
class Result < ApplicationRecord
  belongs_to :study

  enum :result_type, primary: 'Primary', secondary: 'Secondary', empty: ''

  scope :primary, -> { where(result_type: 'Primary') }
  scope :secondary, -> { where(result_type: 'Secondary') }
end
