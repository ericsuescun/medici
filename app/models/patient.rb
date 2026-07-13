# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :date
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  sex                 :string
#  state               :string           default("prospect"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_patients_on_state  (state)
#
class Patient < ApplicationRecord
  include Userable

  # Audit trail for the patient's personal/clinical data and AASM state changes;
  # whodunnit records the acting user (see PaperTrail controller integration).
  has_paper_trail

  has_many :variable_values, dependent: :destroy

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
end
