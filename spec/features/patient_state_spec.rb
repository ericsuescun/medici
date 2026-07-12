require 'rails_helper'

RSpec.feature 'Patient state transitions', type: :feature, js: true do
  let(:admin) { create(:user, :admin) }

  before { login_as admin, scope: :user }

  scenario 'an admin advances a prospect patient to candidate from the patients list' do
    create(:patient) # starts in the prospect state

    visit patients_path

    # A prospect patient exposes the "Evaluar" (assess) transition to an admin.
    expect(page).to have_button('Evaluar')

    click_button 'Evaluar'

    # After assess: prospect -> candidate. Assert on what the user sees (feature
    # specs shouldn't reach into the DB across the server thread): the assess
    # button is gone, the candidate-state actions appear, and the flash confirms.
    expect(page).to have_content('Estado actualizado correctamente.')
    expect(page).to have_no_button('Evaluar')
    expect(page).to have_button('Aceptar')
    expect(page).to have_button('Descartar')
  end
end
