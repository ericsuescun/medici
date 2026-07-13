# == Schema Information
#
# Table name: studies
#
#  id                 :bigint           not null, primary key
#  completed_at       :date
#  exclusion_criteria :string
#  first_patient_at   :date
#  global_ending_at   :date
#  inclusion_criteria :string
#  main_intervention  :string
#  public_title       :string
#  reviewed           :boolean
#  sample_size        :integer
#  scientific_title   :string
#  sex                :string
#  short_title        :string           default("")
#  started_at         :date
#  study_phase        :string
#  study_status       :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  review_user_id     :integer
#  sponsor_id         :bigint           not null
#
# Indexes
#
#  index_studies_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  fk_rails_...  (sponsor_id => sponsors.id)
#
class Study < ApplicationRecord
  belongs_to :sponsor

  has_and_belongs_to_many :trial_center_branches
  has_and_belongs_to_many :users
  has_and_belongs_to_many :medications
  has_many :trial_center_facilities, through: :trial_center_branches

  has_many :articles, dependent: :destroy
  has_many :results, dependent: :destroy
  has_many :trial_cities, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_one :criteria_profile, dependent: :destroy

  enum :study_status, completed: "completed", recruiting: "recruiting"
  enum :study_phase, I: "I", II: "II", III: "III", IV: "IV"

  validates :public_title, :scientific_title, :short_title, presence: true

  def cities_names
    cities = []
    self.trial_center_branches.each do |branch|
      cities.concat(branch.cities)
    end
    cities.uniq
  end
  def current_criteria_profile
    CriteriaProfile.find_by(study_id: id)
  end
end
