require 'rails_helper'

# == Schema Information
#
# Table name: local_parameters
#
#  id           :bigint           not null, primary key
#  description  :string
#  display_name :string
#  name         :string           not null
#  value        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  country_id   :bigint           not null
#
# Indexes
#
#  index_local_parameters_on_country_id           (country_id)
#  index_local_parameters_on_country_id_and_name  (country_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#
RSpec.describe LocalParameter, type: :model do
  it "requires a name and a value, unique per country" do
    colombia = FactoryBot.create(:country, :colombia)
    FactoryBot.create(:local_parameter, country: colombia, name: "local_health_authority", value: "INVIMA")

    duplicate = described_class.new(country: colombia, name: "local_health_authority", value: "OTRO")
    expect(duplicate).not_to be_valid

    expect(described_class.new(country: colombia, name: "x")).not_to be_valid
    expect(described_class.new(country: colombia, value: "x")).not_to be_valid
  end

  it "allows the same parameter name in a different country" do
    FactoryBot.create(:local_parameter, :health_authority)

    argentina = FactoryBot.create(:country, name: "Argentina", code: "AR")
    other = described_class.new(country: argentina, name: described_class::LOCAL_HEALTH_AUTHORITY, value: "ANMAT")

    expect(other).to be_valid
  end

  describe "#label" do
    it "prefers the display name and falls back to the value" do
      parameter = FactoryBot.build(:local_parameter, value: "INVIMA", display_name: nil)
      expect(parameter.label).to eq("INVIMA")

      parameter.display_name = "INVIMA (Colombia)"
      expect(parameter.label).to eq("INVIMA (Colombia)")
    end
  end

  describe ".health_authority_label" do
    it "resolves the default country's health authority" do
      FactoryBot.create(:local_parameter, :health_authority)
      expect(described_class.health_authority_label).to eq("INVIMA")
    end

    it "returns nil when it has not been configured" do
      expect(described_class.health_authority_label).to be_nil
    end

    it "resolves a specific country when asked" do
      FactoryBot.create(:local_parameter, :health_authority)
      argentina = FactoryBot.create(:country, name: "Argentina", code: "AR")
      FactoryBot.create(:local_parameter, country: argentina,
                                          name: described_class::LOCAL_HEALTH_AUTHORITY, value: "ANMAT")

      expect(described_class.health_authority_label(country: argentina)).to eq("ANMAT")
    end
  end
end
