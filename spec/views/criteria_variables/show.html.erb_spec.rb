require 'rails_helper'

RSpec.describe "criteria_variables/show", type: :view do
  it 'renders the qualitative_scale exactly as entered (comma-separated list)' do
    profile = FactoryBot.create(:criteria_profile)
    variable = FactoryBot.create(:criteria_variable, criteria_profile: profile, qualitative_scale: 'low, medium, high')

    assign(:criteria_profile, profile)
    assign(:criteria_variable, variable)
    # The view has an admin-only "Control de cambios" link gated on current_user,
    # which isn't wired up in view specs (no Warden middleware).
    allow(view).to receive(:current_user).and_return(nil)

    render template: 'criteria_variables/show'

    expect(rendered).to include('Escala cualitativa')
    expect(rendered).to include('low, medium, high')
  end
end
