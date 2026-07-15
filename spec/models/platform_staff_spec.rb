require 'rails_helper'

# == Schema Information
#
# Table name: platform_staffs
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
RSpec.describe PlatformStaff, type: :model do
  it { is_expected.to have_one(:user) }

  it "wraps a User as a userable" do
    user = create(:user, :platform_staff)
    expect(user.userable).to be_a(PlatformStaff)
    expect(user.platform_staff?).to be(true)
  end

  it "is assigned the platform_staff role on creation" do
    user = create(:user, :platform_staff)
    expect(user.role.name).to eq("platform_staff")
  end

  it "delegates identity to the user" do
    staff = create(:user, :platform_staff, firstname: "Ana", lastname: "Ruiz").userable
    expect(staff.fullname).to eq("Ana Ruiz")
    expect(staff.email).to be_present
  end
end
