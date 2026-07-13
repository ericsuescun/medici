require 'rails_helper'

# Pseudonymization of identifiable patient data (INVIMA Anexo Técnico Tabla 7).
RSpec.describe "Patient pseudonymization", type: :model do
  let(:patient) do
    FactoryBot.create(:patient,
      firstname: "Juan", lastname: "Pérez", email: "juan@example.com",
      dob: "1990-05-01", contact_number: "3015550000",
      illness_description: "Psoriasis moderada", notes: "control 1")
  end

  def raw_column(id, col)
    Patient.connection.select_value("SELECT #{col} FROM patients WHERE id = #{id}")
  end

  it "stores identifiable fields as ciphertext at rest" do
    %w[firstname lastname email illness_description notes].each do |col|
      stored = raw_column(patient.id, col)
      expect(stored).to be_present
      expect(stored).not_to include(patient.public_send(col))
    end
  end

  it "decrypts transparently on read" do
    reloaded = Patient.find(patient.id)
    expect(reloaded.firstname).to eq("Juan")
    expect(reloaded.fullname).to eq("Juan Pérez")
    expect(reloaded.illness_description).to eq("Psoriasis moderada")
  end

  it "keeps dob usable as a Date despite being an encrypted string column" do
    expect(patient.reload.dob).to eq(Date.new(1990, 5, 1))
  end

  it "supports exact-match search on deterministically-encrypted fields" do
    expect(Patient.where(firstname: "Juan")).to include(patient)
    expect(Patient.where(email: "juan@example.com")).to include(patient)
  end

  it "assigns a unique participant code on create" do
    expect(patient.participant_code).to match(/\AP-[A-Z0-9]{8}\z/)
    other = FactoryBot.create(:patient)
    expect(other.participant_code).not_to eq(patient.participant_code)
  end

  it "owns its identity (reads its own column, not the delegated User)" do
    user = FactoryBot.create(:user, :patient)
    patient = user.userable
    user.update!(firstname: "UserLevelName")
    # Patient reads its own (factory-set) name, not the User's.
    expect(patient.reload.firstname).not_to eq("UserLevelName")
    expect(patient.firstname).to be_present
  end

  it "leaves other user types delegating identity to User (unchanged)" do
    admin_user = FactoryBot.create(:user, :admin, firstname: "Ana", lastname: "Gómez")
    expect(admin_user.userable.firstname).to eq("Ana")
    expect(admin_user.userable.fullname).to eq("Ana Gómez")
  end
end
