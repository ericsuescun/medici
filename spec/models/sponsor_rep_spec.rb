require 'rails_helper'

# == Schema Information
#
# Table name: sponsor_reps
#
#  id              :bigint           not null, primary key
#  contact_address :string
#  contact_number  :string
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  sponsor_id      :bigint
#
# Indexes
#
#  index_sponsor_reps_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  fk_rails_...  (sponsor_id => sponsors.id)
#
RSpec.describe SponsorRep, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
