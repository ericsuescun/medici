# == Schema Information
#
# Table name: patients
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  dob             :date
#  email           :string
#  firstname       :string
#  lastname        :string
#  notes           :text
#  sex             :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_patients_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Patient < ApplicationRecord
  include Userable

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
