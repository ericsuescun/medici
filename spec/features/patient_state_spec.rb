require 'rails_helper'

RSpec.feature 'Patient state transitions', type: :feature, js: true do
  let(:admin) { create(:user, :admin) }

  before { login_as admin, scope: :user }

  scenario 'an admin advances a interested patient to candidate from the patients list' do
    patient = create(:patient) # starts in the interested state

    visit patients_path

    # Scope every assertion to THIS patient's row (dom_id) rather than the whole
    # page. Under transactional fixtures a real-browser (Selenium) spec runs the
    # app server on a separate thread sharing the test connection, and can
    # occasionally see an adjacent example's not-yet-rolled-back patient — which
    # made a page-wide `have_button('Evaluar')` an ambiguous match. Row-scoping
    # makes the spec hermetic regardless of stray rows.
    within "#patient_#{patient.id}" do
      # A interested patient exposes the "Evaluar" (assess) transition to an admin.
      expect(page).to have_button('Evaluar')
      click_button 'Evaluar'
    end

    # After assess: interested -> candidate. Assert on what the user sees (feature
    # specs shouldn't reach into the DB across the server thread): the flash
    # confirms, and within the row the assess button is gone and the
    # candidate-state actions appear.
    expect(page).to have_content('Estado actualizado correctamente.')
    within "#patient_#{patient.id}" do
      expect(page).to have_no_button('Evaluar')
      expect(page).to have_button('Aceptar')
      expect(page).to have_button('Descartar')
    end
  end
end
