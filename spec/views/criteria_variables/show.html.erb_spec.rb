require 'rails_helper'

RSpec.describe "criteria_variables/show", type: :view do
  it 'renders the qualitative_scale exactly as entered (comma-separated list)' do
    profile = FactoryBot.create(:criteria_profile)
    variable = FactoryBot.create(:criteria_variable, criteria_profile: profile, qualitative_scale: 'low, medium, high')

    assign(:criteria_profile, profile)
    assign(:criteria_variable, variable)

    render template: 'criteria_variables/show'

    expect(rendered).to include('Escala cualitativa')
    expect(rendered).to include('low, medium, high')
  end
end
