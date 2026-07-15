require 'rails_helper'

RSpec.feature "Public 'More about this study' card", type: :feature do
  scenario "an anonymous visitor opens the info card from the home showcase" do
    create(:study, public_title: "Vitalia Diabetes Trial", main_intervention: "Metformin XR")

    visit root_path
    expect(page).to have_link(I18n.t("static_pages.showcase.more_about"))
    first(:link, I18n.t("static_pages.showcase.more_about")).click

    expect(page).to have_content("Vitalia Diabetes Trial")
    expect(page).to have_content("Metformin XR")
    expect(page).to have_content(I18n.t("static_pages.study_details.cities"))
    expect(page).to have_content(I18n.t("static_pages.study_details.centers"))
    expect(page).to have_content(I18n.t("static_pages.study_details.has_participants"))
  end

  scenario "shows a 'no' badge when no patient is enrolled" do
    study = create(:study)
    visit study_about_path(study)
    expect(page).to have_css(".badge.bg-secondary", text: I18n.t("common.no"))
  end

  scenario "shows a 'yes' badge once a patient is enrolled" do
    study = create(:study)
    study.users << create(:user, :patient)
    visit study_about_path(study)
    expect(page).to have_css(".badge.bg-success", text: I18n.t("common.yes"))
  end
end
