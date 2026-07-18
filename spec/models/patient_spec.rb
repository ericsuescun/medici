require 'rails_helper'

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
RSpec.describe Patient, type: :model do
  subject(:patient) { FactoryBot.create(:patient) }

  describe "AASM lifecycle" do
    it "starts in the prospect state" do
      expect(patient).to be_prospect
      expect(patient.state).to eq("prospect")
    end

    it "assess: prospect -> candidate" do
      expect { patient.assess! }.to change(patient, :state).from("prospect").to("candidate")
    end

    it "accept: candidate -> participant" do
      patient.assess!
      expect { patient.accept! }.to change(patient, :state).from("candidate").to("participant")
    end

    it "discard: candidate -> prospect" do
      patient.assess!
      expect { patient.discard! }.to change(patient, :state).from("candidate").to("prospect")
    end

    it "reject: participant -> candidate" do
      patient.assess!
      patient.accept!
      expect { patient.reject! }.to change(patient, :state).from("participant").to("candidate")
    end

    it "forbids an illegal transition (accept from prospect)" do
      expect(patient.may_accept?).to be false
      expect { patient.accept! }.to raise_error(AASM::InvalidTransition)
    end
  end
end
