require 'rails_helper'

# Every model holding patient-related data must be versioned so all changes are
# traceable (INVIMA / Resolución 1995 audit-attribution requirement).
RSpec.describe "PaperTrail audit trail on patient-related models", type: :model do
  it "versions a Patient on create and update" do
    patient = FactoryBot.create(:patient)
    expect { patient.update!(notes: "seen in clinic") }
      .to change { patient.versions.count }.by(1)
  end

  it "versions a VariableValue and can attribute it to a user" do
    patient = FactoryBot.create(:patient)
    physician = FactoryBot.create(:user, :admin)
    value = patient.variable_values.create!(
      name: "Edad", value_type: "quantitative", comparison_type: "equal",
      variable_type: "inclusion", value: "30", entered_by: physician
    )

    expect(value.versions).to be_present
    expect(value.entered_by).to eq(physician)
  end

  it "versions a CriteriaVariable (an eligibility rule change)" do
    profile = FactoryBot.create(:criteria_profile)
    variable = FactoryBot.create(:criteria_variable, criteria_profile: profile)
    expect { variable.update!(reference_value_1: 21) }
      .to change { variable.versions.count }.by(1)
  end

  it "versions a CriteriaProfile" do
    profile = FactoryBot.create(:criteria_profile)
    expect { profile.update!(name: "Updated profile") }
      .to change { profile.versions.count }.by(1)
  end

  it "versions a Study (status/phase changes affect eligibility)" do
    study = FactoryBot.create(:study)
    expect { study.update!(study_status: "completed") }
      .to change { study.versions.count }.by(1)
  end
end
