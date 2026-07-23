# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :string
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  participant_code    :string
#  sex                 :string
#  state               :string           default("interested"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  study_id            :bigint
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_state             (state)
#  index_patients_on_study_id          (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
class Patient < ApplicationRecord
  include Userable

  # Backs the habeas-data checkbox on the public participation form. Not a
  # column: what was agreed is persisted as an immutable Consent record, never
  # as a mutable boolean on the patient.
  attr_accessor :data_processing_authorization

  # Pseudonymization (INVIMA Anexo Técnico Tabla 7): the patient owns its own
  # identity/clinical columns (it does NOT delegate identity to the shared User —
  # see DelegatesIdentityToUser), and those columns are encrypted at rest.
  #
  # Deterministic for the fields we search/look a patient up by (exact-match
  # queries + unique-ish identifiers); non-deterministic (stronger) for free-text
  # clinical data we never query by value. Patient#email is NOT the Devise login
  # (that stays on User), so encrypting it here has no auth impact.
  ENCRYPTED_DETERMINISTIC = %i[firstname lastname email dob contact_number contact_address id_number].freeze
  ENCRYPTED_NON_DETERMINISTIC = %i[illness_description notes].freeze

  # dob is stored as a string column (ciphertext can't live in a date column) but
  # still behaves as a Date in Ruby.
  attribute :dob, :date

  encrypts(*ENCRYPTED_DETERMINISTIC, deterministic: true)
  encrypts(*ENCRYPTED_NON_DETERMINISTIC)

  # Audit trail for AASM state changes and non-sensitive attributes. Skip the
  # encrypted fields so their plaintext is never copied into the versions table
  # (which lives in the same database) — the audit log must not defeat encryption.
  has_paper_trail skip: (ENCRYPTED_DETERMINISTIC + ENCRYPTED_NON_DETERMINISTIC)

  has_many :variable_values, dependent: :destroy

  # Clinical SOAP notes accumulated over the course of the research.
  has_many :soap_notes, dependent: :destroy

  # Patient-contributed complementary information (prior exams: PDFs, images, notes).
  has_one :complementary_information, dependent: :destroy

  # A patient exists to be considered for one study. This used to live on the
  # patient's User account (User has_and_belongs_to_many :studies) because a
  # patient could only be created by signing up; patients are records now, so the
  # study belongs to the patient.
  belongs_to :study

  # The habeas-data authorizations this patient granted (Ley 1581 de 2012).
  has_many :consents, dependent: :destroy

  # A non-identifying code linking research/eligibility data back to the patient
  # by code rather than identity.
  before_create :assign_participant_code
  validates :participant_code, uniqueness: true, allow_nil: true

  # Neither contact field is mandatory on its own — a prospective patient may
  # leave a phone, an email, or both. But a lead with no way to reach them is
  # useless: the whole point is that a centre rep calls them back.
  validate :some_way_to_make_contact

  def fullname
    [ firstname, lastname ].compact_blank.join(" ")
  end

  # Patients whose study runs at one of `branches` — the scoping rule for a
  # trial centre rep, who must only ever see the patients of their own centre.
  scope :for_trial_center_branches, ->(branches) {
    joins(study: :trial_center_branches)
      .where(trial_center_branches: { id: branches })
      .distinct
  }

  include AASM

  aasm column: :state do
    state :interested, initial: true
    state :candidate
    state :participant

    event :assess do
      transitions from: :interested, to: :candidate
    end

    event :accept do
      transitions from: :candidate, to: :participant
    end

    event :discard do
      transitions from: :candidate, to: :interested
    end

    event :reject do
      transitions from: :participant, to: :candidate
    end
  end

  private

  def some_way_to_make_contact
    return if contact_number.present? || email.present?

    errors.add(:base, I18n.t("patients.contact_method_required"))
  end

  def assign_participant_code
    return if participant_code.present?

    self.participant_code = loop do
      candidate = "P-#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless Patient.exists?(participant_code: candidate)
    end
  end
end
