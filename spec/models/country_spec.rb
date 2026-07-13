require 'rails_helper'

# == Schema Information
#
# Table name: countries
#
#  id               :bigint           not null, primary key
#  code             :string           not null
#  country_priority :integer          default(4), not null
#  name             :string           not null
#  phone_prefix     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_countries_on_code              (code) UNIQUE
#  index_countries_on_country_priority  (country_priority)
#
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
