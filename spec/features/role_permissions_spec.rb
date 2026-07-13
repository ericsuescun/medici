require 'rails_helper'

# Proves the UI honors the permission matrix: controls the current role can't
# use are hidden, and direct URL access is refused. Server-rendered gating, so
# rack_test (no JS) is enough.
RSpec.feature 'Role-based UI gating', type: :feature do
  scenario 'a patient (Medication: show-only) sees no management controls' do
    FactoryBot.create(:medication)
    login_as(FactoryBot.create(:user, :patient), scope: :user)

    visit medications_path

    expect(page).to have_content('Medicamentos')
    expect(page).to have_no_link('Nuevo medicamento')
    expect(page).to have_no_link('Editar')
    expect(page).to have_no_button('Eliminar')
  end

  scenario 'a patient hitting an edit URL directly is refused' do
    medication = FactoryBot.create(:medication)
    login_as(FactoryBot.create(:user, :patient), scope: :user)

    visit edit_medication_path(medication)

    expect(page).to have_content('No está autorizado')
    expect(page).to have_current_path(root_path, ignore_query: true)
  end

  scenario 'an admin sees the management controls' do
    FactoryBot.create(:medication)
    login_as(FactoryBot.create(:user, :admin), scope: :user)

    visit medications_path

    expect(page).to have_link('Nuevo medicamento')
    expect(page).to have_link('Editar')
    expect(page).to have_button('Eliminar')
  end
end
