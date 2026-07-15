require "rails_helper"

# The consent gate as a person actually meets it. Needs a real browser: the
# enable/disable is Stimulus, and rack_test runs no JS.
#
# The server-side gate (nothing is written without authorization) is covered in
# spec/requests/participation_requests_spec.rb — that is the one that matters for
# compliance. This covers the affordance in front of it.
RSpec.feature "Participation request consent gate", type: :feature, js: true do
  let(:study) { create(:study, public_title: "Estudio Dermatitis") }

  before { visit new_participation_request_path(study_id: study.id) }

  def submit_disabled?
    page.evaluate_script("document.querySelector('input[type=submit]').disabled")
  end

  it "shows the authorization text above the checkbox, not beside it" do
    positions = page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector('#patient_data_processing_authorization');
        const copy = document.querySelector('.form-check').previousElementSibling;
        return {
          copyBottom: copy.getBoundingClientRect().bottom,
          checkboxTop: box.getBoundingClientRect().top
        };
      })()
    JS

    expect(positions["copyBottom"]).to be <= positions["checkboxTop"] + 1
  end

  it "keeps the submit button disabled until the box is ticked" do
    expect(submit_disabled?).to be(true)

    check "patient_data_processing_authorization"
    expect(submit_disabled?).to be(false)
  end

  it "disables it again if the box is un-ticked" do
    check "patient_data_processing_authorization"
    uncheck "patient_data_processing_authorization"

    expect(submit_disabled?).to be(true)
  end

  it "submits once authorized, recording the patient and the consent" do
    check "patient_data_processing_authorization"
    fill_in I18n.t("participation_requests.contact_number"), with: "300 111 2222"

    expect {
      click_button I18n.t("participation_requests.submit")
      expect(page).to have_content(I18n.t("participation_requests.thanks"))
    }.to change(Patient, :count).by(1).and change(Consent, :count).by(1)

    expect(Patient.last.study).to eq(study)
  end
end
