require 'rails_helper'

RSpec.describe Country, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:phone_prefix) }

    it 'validates uniqueness of code case-insensitively' do
      described_class.create!(name: 'Colombia', code: 'CO', phone_prefix: '+57')
      dup = described_class.new(name: 'Colombia 2', code: 'co', phone_prefix: '+057')
      expect(dup.valid?).to be false
      expect(dup.errors[:code]).to be_present
    end

    it 'validates phone_prefix format' do
      country = described_class.new(name: 'Test', code: 'TS', phone_prefix: '57')
      expect(country.valid?).to be false
      expect(country.errors[:phone_prefix]).to be_present
    end
  end
end
