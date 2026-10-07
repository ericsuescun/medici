require "rails_helper"
require Rails.root.join("db/seeds/example_criteria_profiles")

# fill_missing_prompts! runs against production's demo data, where REAL studies
# also carry example profiles — so "only the studies it was told" is the
# property that keeps a question from reaching a real study's applicants.
RSpec.describe ExampleCriteriaProfiles, ".fill_missing_prompts!" do
  let(:owner) { FactoryBot.create(:user, :admin) }

  # A profile as an older seed built it: the example rules, no specific prompts.
  def legacy_profile_for(study)
    ExampleCriteriaProfiles.build_profile!(study, ExampleCriteriaProfiles::AREA_NAMES.first, owner).tap do |profile|
      profile.criteria_variables.where(criteria_category: "specific").update_all(patient_prompt: nil)
    end
  end

  def specific_prompted(profile)
    profile.criteria_variables.where(criteria_category: "specific").where.not(patient_prompt: [ nil, "" ]).count
  end

  it "fills the specific prompts an older seed left blank" do
    profile = legacy_profile_for(FactoryBot.create(:study))

    expect(ExampleCriteriaProfiles.fill_missing_prompts!).to eq(6)
    expect(specific_prompted(profile)).to eq(6)
  end

  it "touches only the studies it is given" do
    demo = legacy_profile_for(FactoryBot.create(:study))
    real = legacy_profile_for(FactoryBot.create(:study))

    ExampleCriteriaProfiles.fill_missing_prompts!(studies: [ demo.study_id ])

    expect(specific_prompted(demo)).to eq(6)
    expect(specific_prompted(real)).to eq(0)
  end

  it "never rewrites a prompt somebody edited" do
    profile = legacy_profile_for(FactoryBot.create(:study))
    visits = profile.criteria_variables.find_by!(name: "Disponibilidad para visitas presenciales")
    visits.update!(patient_prompt: "¿Puede venir los martes?")

    ExampleCriteriaProfiles.fill_missing_prompts!

    expect(visits.reload.patient_prompt).to eq("¿Puede venir los martes?")
  end

  it "is idempotent" do
    legacy_profile_for(FactoryBot.create(:study))
    ExampleCriteriaProfiles.fill_missing_prompts!

    expect(ExampleCriteriaProfiles.fill_missing_prompts!).to eq(0)
  end
end
