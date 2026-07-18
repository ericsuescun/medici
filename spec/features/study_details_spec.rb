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
    # A real Patient record (patients.study_id) — enrollment stopped flowing
    # through the studies_users join when patient accounts were removed.
    create(:patient, study: study)
    visit study_about_path(study)
    expect(page).to have_css(".badge.bg-success", text: I18n.t("common.yes"))
  end

  # Regression: `.stat-card` sets height:100% for the equal-height tiles on the
  # home page. Here the stat card is one of three stacked panels, so 100%
  # resolved to the whole column — it ballooned and pushed the contact card and
  # the participate CTA clean outside the column, overlapping the card below.
  # This was broken at every width, not only on phones. Needs a real browser:
  # rack_test computes no geometry.
  context "layout", js: true do
    let(:study) do
      create(:study).tap do |s|
        s.contacts.create!(firstname: "Ana", lastname: "Gómez", email1: "ana@example.com")
      end
    end

    # Bottom edge of each element in the left column vs the column's own bottom.
    ESCAPES = <<~JS.freeze
      (() => {
        const col = document.querySelector('.row > .col-lg-4');
        const bottom = el => el.getBoundingClientRect().bottom;
        return Array.from(col.children).some(el => bottom(el) > bottom(col) + 1);
      })()
    JS

    ORDER = <<~JS.freeze
      (() => {
        const col = document.querySelector('.row > .col-lg-4');
        const top = sel => col.querySelector(sel).getBoundingClientRect().top;
        return { cta: top('a.btn-success'), stat: top('.stat-card') };
      })()
    JS

    it "keeps the whole left column inside its bounds on mobile" do
      page.driver.browser.manage.window.resize_to(390, 844)
      visit study_about_path(study)

      expect(page).to have_css("a.btn-success")
      expect(page.evaluate_script(ESCAPES)).to be(false)
    end

    it "leads with the participate CTA on mobile" do
      page.driver.browser.manage.window.resize_to(390, 844)
      visit study_about_path(study)

      expect(page).to have_css("a.btn-success")
      pos = page.evaluate_script(ORDER)
      expect(pos["cta"]).to be < pos["stat"]
    end

    it "keeps the CTA below the cards on desktop" do
      page.driver.browser.manage.window.resize_to(1400, 1000)
      visit study_about_path(study)

      expect(page).to have_css("a.btn-success")
      expect(page.evaluate_script(ESCAPES)).to be(false)
      pos = page.evaluate_script(ORDER)
      expect(pos["cta"]).to be > pos["stat"]
    end
  end
end
