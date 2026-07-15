require 'rails_helper'

RSpec.feature "Platform staff management", type: :feature do
  scenario "an admin creates a platform staff member" do
    login_as create(:user, :admin), scope: :user

    visit platform_staffs_path
    click_link I18n.t("platform_staffs.new")

    fill_in I18n.t("platform_staffs.firstname"), with: "Ana"
    fill_in I18n.t("platform_staffs.lastname"), with: "Ruiz"
    fill_in I18n.t("platform_staffs.email"), with: "ana.cm@example.com"
    fill_in I18n.t("platform_staffs.password"), with: "12345678"
    fill_in I18n.t("platform_staffs.password_confirmation"), with: "12345678"
    fill_in PlatformStaff.human_attribute_name(:title), with: "Community Manager"

    find('input[type="submit"]').click

    expect(page).to have_content("Ana Ruiz")
    expect(PlatformStaff.count).to eq(1)
    expect(User.find_by(email: "ana.cm@example.com").platform_staff?).to be(true)
  end
end
