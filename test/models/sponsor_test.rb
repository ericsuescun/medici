# == Schema Information
#
# Table name: sponsors
#
#  id           :bigint           not null, primary key
#  initials     :string
#  name         :string
#  shortname    :string
#  sponsor_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require "test_helper"

class SponsorTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
