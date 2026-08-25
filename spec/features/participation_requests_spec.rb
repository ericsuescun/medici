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

  # Waiting matchers, not an instant evaluate_script: the button starts
  # enabled by design (no-JS fail-open; the server is the real gate) and
  # Stimulus disables it on connect — an instant check can race that boot
  # and flake (it did, twice, on 2026-07-18).
  def expect_submit_disabled
    expect(page).to have_button(I18n.t("participation_requests.submit"), disabled: true)
  end

  def expect_submit_enabled
    expect(page).to have_button(I18n.t("participation_requests.submit"), disabled: false)
  end

  it "shows the authorization text above the checkbox, not beside it" do
    positions = page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector('#patient_data_processing_authorization');
        const copy = document.querySelector('.consent-row').previousElementSibling;
        return {
          copyBottom: copy.getBoundingClientRect().bottom,
          checkboxTop: box.getBoundingClientRect().top
        };
      })()
    JS

    expect(positions["copyBottom"]).to be <= positions["checkboxTop"] + 1
  end

  it "keeps the submit button disabled until the box is ticked" do
    expect_submit_disabled

    check "patient_data_processing_authorization"
    expect_submit_enabled
  end

  it "disables it again if the box is un-ticked" do
    check "patient_data_processing_authorization"
    uncheck "patient_data_processing_authorization"

    expect_submit_disabled
  end

  # The authorization is a legal act, so its state has to be readable at a glance
  # rather than hidden in a 16px dot.
  it "marks the consent row as granted once ticked" do
    expect(page).to have_css(".consent-row")
    expect(page).not_to have_css(".consent-row.consent-row--granted")

    check "patient_data_processing_authorization"

    expect(page).to have_css(".consent-row.consent-row--granted")
  end

  it "gives the checkbox a real tap target" do
    size = page.evaluate_script(
      "(() => { const r = document.querySelector('#patient_data_processing_authorization')" \
      ".getBoundingClientRect(); return Math.round(Math.min(r.width, r.height)); })()"
    )

    expect(size).to be >= 20
  end

  describe "the disabled-button hint" do
    it "explains why the button is dead" do
      expect(page).to have_content(I18n.t("participation_requests.check_to_continue"))
    end

    it "goes away once authorization is given" do
      check "patient_data_processing_authorization"

      expect(page).not_to have_content(I18n.t("participation_requests.check_to_continue"))
    end
  end

  it "submits once authorized, recording the patient and the consent" do
    check "patient_data_processing_authorization"
    check "patient_adult_confirmed"
    fill_in I18n.t("participation_requests.contact_number"), with: "300 111 2222"

    expect {
      click_button I18n.t("participation_requests.submit")
      expect(page).to have_content(I18n.t("participation_requests.thanks"))
    }.to change(Patient, :count).by(1).and change(Consent, :count).by(1)

    expect(Patient.last.study).to eq(study)
  end
end
