require 'rails_helper'

RSpec.describe GlobalSearch do
  def group(groups, type)
    groups.find { |g| g.type == type }
  end

  # Two branches, each with its own study, patient and city.
  let(:branch_a) { FactoryBot.create(:trial_center_branch, name: "Centro Norte") }
  let(:branch_b) { FactoryBot.create(:trial_center_branch, name: "Centro Sur") }
  let(:city_a) { FactoryBot.create(:city, name: "Bogotá Alpha") }
  let(:city_b) { FactoryBot.create(:city, name: "Bogotá Beta") }

  # A city is linked to studies through the branch: branch has cities AND studies.
  let(:study_a) do
    FactoryBot.create(:study, public_title: "Estudio Alpha").tap do |s|
      s.trial_center_branches << branch_a
      branch_a.cities << city_a
    end
  end
  let(:study_b) do
    FactoryBot.create(:study, public_title: "Estudio Beta").tap do |s|
      s.trial_center_branches << branch_b
      branch_b.cities << city_b
    end
  end

  let!(:patient_a) { FactoryBot.create(:patient, firstname: "Alicia", lastname: "Alpha", study: study_a) }
  let!(:patient_b) { FactoryBot.create(:patient, firstname: "Alberto", lastname: "Beta", study: study_b) }

  before { study_a; study_b } # force creation of the join data

  describe "an admin" do
    let(:user) { FactoryBot.create(:user, :admin) }

    it "finds studies across all branches" do
      groups = described_class.new(user: user, query: "Estudio").call
      expect(group(groups, :studies).records).to include(study_a, study_b)
    end

    it "finds a patient by exact name" do
      groups = described_class.new(user: user, query: "Alicia").call
      expect(group(groups, :patients).records).to include(patient_a)
    end

    it "finds cities and lists their studies" do
      groups = described_class.new(user: user, query: "Bogotá").call
      cities = group(groups, :cities).records
      alpha = cities.find { |c| c.city == city_a }
      expect(alpha.studies).to include(study_a)
    end
  end

  describe "a trial centre rep (scoped to branch A)" do
    let(:user) do
      FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
    end

    it "finds its own branch's study but not another branch's" do
      groups = described_class.new(user: user, query: "Estudio").call
      records = group(groups, :studies).records
      expect(records).to include(study_a)
      expect(records).not_to include(study_b)
    end

    it "finds its own branch's patient but not another branch's" do
      groups = described_class.new(user: user, query: "Al").call
      # 'Al' matches both by prefix, but only exact names match (encryption) —
      # search the exact names instead.
      own = described_class.new(user: user, query: "Alicia").call
      expect(group(own, :patients)&.records.to_a).to include(patient_a)

      others = described_class.new(user: user, query: "Alberto").call
      expect(group(others, :patients)&.records.to_a).not_to include(patient_b)
    end

    it "shows a city with only its own branch's studies" do
      groups = described_class.new(user: user, query: "Bogotá").call
      cities = group(groups, :cities).records
      # City B belongs to branch B, so the rep should not even see it.
      expect(cities.map(&:city)).to include(city_a)
      expect(cities.map(&:city)).not_to include(city_b)
      expect(cities.find { |c| c.city == city_a }.studies).to include(study_a)
    end
  end

  describe "a sponsor rep" do
    let(:user) { FactoryBot.create(:user, :sponsor_rep) }

    it "can find studies" do
      groups = described_class.new(user: user, query: "Estudio").call
      expect(group(groups, :studies).records).to include(study_a, study_b)
    end

    it "gets no patients group (no Patient permission)" do
      groups = described_class.new(user: user, query: "Alicia").call
      expect(group(groups, :patients)).to be_nil
    end
  end

  it "returns nothing for a blank query" do
    admin = FactoryBot.create(:user, :admin)
    expect(described_class.new(user: admin, query: "   ").call).to eq([])
  end
end
