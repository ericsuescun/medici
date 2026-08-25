# Testimony, not measurement: what the patient (or a rep transcribing a phone
# or paper answer) DECLARED about themselves. Kept structurally apart from
# VariableValue, the investigator-verified measurement that feeds the promotion
# gate — see the migration comment for the columns this table deliberately
# lacks. A declaration can only ever be judged by handing its raw `answer` to
# the LIVE rule (`CriteriaVariable#satisfied_by?`), which is what
# `CriteriaProfile#evaluate_self_reports` does for the triage tier.
#
# Do NOT include CriteriaComparable here, add comparison/reference columns, or
# rename `answer` to `value` — each of those absences is a lock that keeps a
# self-reported claim from being scored as if it were a measurement.
# == Schema Information
#
# Table name: patient_declarations
#
#  id                   :bigint           not null, primary key
#  answer               :string
#  capture_mode         :string           default("public_form"), not null
#  declared_at          :datetime         not null
#  declined             :boolean          default(FALSE), not null
#  prompt               :text             not null
#  qualitative_scale    :text             default([]), not null, is an Array
#  superseded_at        :datetime
#  value_type           :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  criteria_variable_id :bigint
#  patient_id           :bigint           not null
#  recorded_by_id       :bigint
#
# Indexes
#
#  index_live_declarations_on_patient_and_variable     (patient_id,criteria_variable_id) UNIQUE WHERE (superseded_at IS NULL)
#  index_patient_declarations_on_criteria_variable_id  (criteria_variable_id)
#  index_patient_declarations_on_patient_id            (patient_id)
#  index_patient_declarations_on_recorded_by_id        (recorded_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_variable_id => criteria_variables.id) ON DELETE => nullify
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (recorded_by_id => users.id)
#
class PatientDeclaration < ApplicationRecord
  belongs_to :patient
  # nullify on rule deletion: the testimony outlives the rule as a record.
  belongs_to :criteria_variable, optional: true
  # The staff user who transcribed it; nil = the patient typed it themselves.
  belongs_to :recorded_by, class_name: "User", optional: true

  # Health data declared by an identifiable person: encrypted like the other
  # clinical free text, and kept out of the versions table.
  encrypts :answer

  has_paper_trail skip: [ :answer ]

  enum :capture_mode, public_form: "public_form", interview: "interview"

  validates :prompt, presence: true
  validates :value_type, presence: true
  validates :declared_at, presence: true
  # An answer or an explicit "No sé" — a row with neither says nothing.
  validate :answered_or_declined

  # The declarations that currently speak for the patient.
  scope :live, -> { where(superseded_at: nil) }

  # Append-only by design: a re-answer supersedes the old row instead of
  # editing it, so the audit trail keeps every version of the testimony.
  def supersede!
    update!(superseded_at: Time.current)
  end

  private

  def answered_or_declined
    return if declined? || answer.present?

    errors.add(:base, I18n.t("patient_declarations.answer_or_decline_required"))
  end
end
