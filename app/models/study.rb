# == Schema Information
#
# Table name: studies
#
#  id                              :bigint           not null, primary key
#  committee_approved              :boolean          default(FALSE), not null
#  completed_at                    :date
#  exclusion_criteria              :string
#  first_patient_at                :date
#  global_ending_at                :date
#  inclusion_criteria              :string
#  local_health_authority_approved :boolean          default(FALSE), not null
#  main_intervention               :string
#  patient_self_report_enabled     :boolean          default(FALSE), not null
#  public_title                    :string
#  reviewed                        :boolean
#  sample_size                     :integer
#  scientific_title                :string
#  sex                             :string
#  short_title                     :string           default("")
#  started_at                      :date
#  study_phase                     :string
#  study_status                    :string
#  study_type                      :string
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  review_user_id                  :integer
#  sponsor_id                      :bigint           not null
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
  # Audit trail: study status/phase changes affect enrolled patients' eligibility.
  has_paper_trail

  belongs_to :sponsor

  # Whether enrolling in this study implies a cross-border transfer of patient
  # data to a foreign sponsor (Ley 1581 Art. 26).
  def international_sponsor?
    !!sponsor&.international?
  end

  has_and_belongs_to_many :trial_center_branches
  has_and_belongs_to_many :users
  has_and_belongs_to_many :medications
  # Therapeutic areas (reference data, see Category). 1..3 per study by
  # convention; powers the public home filter and search category counts.
  has_and_belongs_to_many :categories
  has_many :trial_center_facilities, through: :trial_center_branches

  # The study's enrollment (patients.study_id) — Patient has owned the inverse
  # since patients stopped being Users, but this side was never declared.
  # restrict, not destroy: patients are clinical records; a study with
  # enrollment must not be deletable in one stroke (the DB's FK already
  # blocked it — this surfaces the rule at the model layer).
  has_many :patients, dependent: :restrict_with_error

  has_many :articles, dependent: :destroy
  has_many :results, dependent: :destroy
  has_many :trial_cities, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  # Ordered on purpose. `has_one` emits LIMIT 1 with no ORDER BY, so with two
  # rows pointing at the same study which one wins is physical row order — it
  # flips when a row is merely updated. That is load-bearing now: this profile is
  # what gates a patient's promotion (Patient#eligibility_result), so an
  # unstable answer here silently changes who may be promoted. A partial unique
  # index enforces one-per-study; this ordering is the belt to that braces.
  has_one :criteria_profile, -> { order(:id) }, dependent: :destroy

  enum :study_status, completed: "completed", recruiting: "recruiting"
  enum :study_phase, I: "I", II: "II", III: "III", IV: "IV"
  # Observational research assigns no intervention — what it needs signed off is
  # the ethics committee. Interventional research administers something, so the
  # local health authority (INVIMA in Colombia) is the approval that matters.
  # Which of the two approval flags the form asks about follows from this.
  enum :study_type, observational: "observational", interventional: "interventional"

  validates :study_type, presence: true

  validates :public_title, :scientific_title, :short_title, presence: true
  validates :sample_size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # The recruitment goal — how many patients the study needs — IS the study's
  # sample size; aliased so the recruitment-bar code reads as domain language.
  alias_attribute :recruitment_goal, :sample_size

  # Name a study with this, never `public_title` raw. `public_title` is optional
  # and `short_title` can be blank too, so every listing that names a study was
  # hand-rolling `public_title.presence || short_title.presence || fallback` —
  # four copies, and the patients index used a different fallback from the rest.
  # Same reasoning as Patient#display_name.
  def display_title
    public_title.presence || short_title.presence || "##{id}"
  end

  # Prefer RecruitmentProgress.for(studies) when rendering a whole listing.
  def recruitment_progress
    RecruitmentProgress.for(self).fetch(id)
  end

  # Home-page category filter: studies attached to the given therapeutic area.
  # A study with no category only appears under "Todos los estudios".
  scope :by_category, ->(category_id) { joins(:categories).where(categories: { id: category_id }) }

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

  # The approval flag this study's type is judged by — the form asks about this
  # one and only this one.
  def approval_attribute
    observational? ? :committee_approved : :local_health_authority_approved
  end

  def approved?
    public_send(approval_attribute)
  end

  # Whether ANY patient is enrolled (used by the public info card, which shows a
  # yes/no badge — never a count — to avoid disclosing enrollment numbers).
  def any_patient_enrolled?
    patients.exists?
  end
end
