require 'rails_helper'

# == Schema Information
#
# Table name: admins
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
RSpec.describe Admin, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
