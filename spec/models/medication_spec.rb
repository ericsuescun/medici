require 'rails_helper'

# == Schema Information
#
# Table name: medications
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
RSpec.describe Medication, type: :model do
  describe "associations" do
    it { should have_and_belong_to_many(:studies) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end

  describe "default scope" do
    it "orders medications by name in ascending order" do
      medication1 = FactoryBot.create(:medication, name: "Zyrtec")
      medication2 = FactoryBot.create(:medication, name: "Aspirin")
      medication3 = FactoryBot.create(:medication, name: "Metformin")

      expect(Medication.all.to_a).to eq([ medication2, medication3, medication1 ])
    end
  end
end
