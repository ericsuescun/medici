# == Schema Information
#
# Table name: studies
#
#  id                 :bigint           not null, primary key
#  completed_at       :date
#  exclusion_criteria :string
#  first_patient_at   :date
#  global_ending_at   :date
#  inclusion_criteria :string
#  main_intervention  :string
#  public_title       :string
#  reviewed           :boolean
#  sample_size        :integer
#  scientific_title   :string
#  sex                :string
#  short_title        :string           default("")
#  started_at         :date
#  study_phase        :string
#  study_status       :string
#  topic              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  review_user_id     :integer
#  sponsor_id         :bigint           not null
#
# Indexes
#
#  index_studies_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  fk_rails_...  (sponsor_id => sponsors.id)
#
require 'rails_helper'

RSpec.describe Study, type: :model do
  describe "associations" do
    it { should belong_to(:sponsor) }
    it { should have_and_belong_to_many(:trial_center_branches) }
    it { should have_and_belong_to_many(:users) }
    it { should have_and_belong_to_many(:medications) }
    it { should have_many(:trial_center_facilities).through(:trial_center_branches) }
    it { should have_many(:articles).dependent(:destroy) }
    it { should have_many(:results).dependent(:destroy) }
    it { should have_many(:trial_cities).dependent(:destroy) }
    it { should have_many(:contacts).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:public_title) }
    it { should validate_presence_of(:scientific_title) }
  end

  describe "enumerations" do
    it { should define_enum_for(:study_status).with_values(completed: 'completed', recruiting: 'recruiting').backed_by_column_of_type(:string) }
    it { should define_enum_for(:study_phase).with_values(I: 'I', II: 'II', III: 'III', IV: 'IV').backed_by_column_of_type(:string) }
  end

  describe "database columns" do
    it { should have_db_column(:id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:completed_at).of_type(:date) }
    it { should have_db_column(:exclusion_criteria).of_type(:string) }
    it { should have_db_column(:first_patient_at).of_type(:date) }
    it { should have_db_column(:global_ending_at).of_type(:date) }
    it { should have_db_column(:inclusion_criteria).of_type(:string) }
    it { should have_db_column(:main_intervention).of_type(:string) }
    it { should have_db_column(:public_title).of_type(:string) }
    it { should have_db_column(:reviewed).of_type(:boolean) }
    it { should have_db_column(:sample_size).of_type(:integer) }
    it { should have_db_column(:scientific_title).of_type(:string) }
    it { should have_db_column(:sex).of_type(:string) }
    it { should have_db_column(:started_at).of_type(:date) }
    it { should have_db_column(:study_phase).of_type(:string) }
    it { should have_db_column(:study_status).of_type(:string) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
    it { should have_db_column(:review_user_id).of_type(:integer) }
    it { should have_db_column(:sponsor_id).of_type(:integer).with_options(null: false) }
  end

  describe "database indexes" do
    it { should have_db_index(:sponsor_id) }
  end

  describe "instance methods" do
    describe "#cities_names" do
      it "returns unique city names from trial center facilities" do
        study = FactoryBot.create(:study)
        facility1 = FactoryBot.create(:trial_center_facility)
        facility2 = FactoryBot.create(:trial_center_facility)
        branch1 = FactoryBot.create(:trial_center_branch, trial_center_facility: facility1)
        branch2 = FactoryBot.create(:trial_center_branch, trial_center_facility: facility2)

        city1 = FactoryBot.create(:city, name: "City1")
        city2 = FactoryBot.create(:city, name: "City2")
        city3 = FactoryBot.create(:city, name: "City3")

        branch1.cities << city1
        branch1.cities << city2
        branch2.cities << city2
        branch2.cities << city3

        study.trial_center_branches << branch1
        study.trial_center_branches << branch2

        expect(study.cities_names).to match_array([ city1, city2, city3 ])
      end
    end
  end
end
