require 'rails_helper'

RSpec.describe IdType, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:country_code) }
    it { should validate_length_of(:country_code).is_equal_to(2) }

    it 'validates uniqueness of code scoped to country_code' do
      described_class.create!(name: 'Cedula', code: 'CC', country_code: 'CO')
      duplicate = described_class.new(name: 'Other', code: 'CC', country_code: 'CO')
      expect(duplicate.valid?).to be false
      expect(duplicate.errors[:code]).to be_present
    end
  end

  describe 'scopes' do
    it 'filters by country using by_country' do
      it_co = described_class.create!(name: 'Cedula', code: 'CC', country_code: 'CO')
      it_mx = described_class.create!(name: 'CURP', code: 'CURP', country_code: 'MX')
      expect(described_class.by_country('co')).to include(it_co)
      expect(described_class.by_country('co')).not_to include(it_mx)
    end

    it 'returns only active with active scope' do
      active = described_class.create!(name: 'Cedula', code: 'CC', country_code: 'CO', active: true)
      inactive = described_class.create!(name: 'Pasaporte', code: 'PAS', country_code: 'CO', active: false)
      expect(described_class.active).to include(active)
      expect(described_class.active).not_to include(inactive)
    end
  end
end
