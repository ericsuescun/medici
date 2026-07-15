require 'rails_helper'

RSpec.describe "PlatformStaffs", type: :request do
  let(:staff_params) do
    {
      platform_staff: {
        title: "Community Manager",
        contact_number: "3001234567",
        user_attributes: {
          firstname: "Ana", lastname: "Ruiz", email: "ana.cm@example.com",
          password: "12345678", password_confirmation: "12345678"
        }
      }
    }
  end

  it "lets an admin create platform staff (and its User)" do
    sign_in create(:user, :admin), scope: :user
    expect {
      post platform_staffs_path, params: staff_params
    }.to change(PlatformStaff, :count).by(1).and change(User, :count).by(1)
    expect(User.find_by(email: "ana.cm@example.com").platform_staff?).to be(true)
  end

  it "blocks a sponsor_rep from the platform staff index" do
    sign_in create(:user, :sponsor_rep), scope: :user
    get platform_staffs_path
    expect(response).to have_http_status(:redirect)
  end

  it "blocks a patient from creating platform staff" do
    sign_in create(:user, :patient), scope: :user
    expect {
      post platform_staffs_path, params: staff_params
    }.not_to change(PlatformStaff, :count)
  end
end
