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
#  state               :string           default("prospect"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_state             (state)
#
class Patient < ApplicationRecord
  include Userable

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

  # A non-identifying code linking research/eligibility data back to the patient
  # by code rather than identity.
  before_create :assign_participant_code
  validates :participant_code, uniqueness: true, allow_nil: true

  def fullname
    [ firstname, lastname ].compact_blank.join(" ")
  end

  include AASM

  aasm column: :state do
    state :prospect, initial: true
    state :candidate
    state :participant

    event :assess do
      transitions from: :prospect, to: :candidate
    end

    event :accept do
      transitions from: :candidate, to: :participant
    end

    event :discard do
      transitions from: :candidate, to: :prospect
    end

    event :reject do
      transitions from: :participant, to: :candidate
    end
  end

  private

  def assign_participant_code
    return if participant_code.present?

    self.participant_code = loop do
      candidate = "P-#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless Patient.exists?(participant_code: candidate)
    end
  end
end
