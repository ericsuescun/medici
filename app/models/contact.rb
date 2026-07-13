# == Schema Information
#
# Table name: contacts
#
#  id         :bigint           not null, primary key
#  address1   :string
#  address2   :string
#  comments   :text
#  email1     :string
#  email2     :string
#  firstname  :string
#  lastname   :string
#  number1    :string
#  number2    :string
#  title1     :string
#  title2     :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  study_id   :bigint           not null
#
# Indexes
#
#  index_contacts_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
class Contact < ApplicationRecord
  belongs_to :study

  def fullname
    firstname + " " + lastname
  end

  def contact_info
    "Email: #{email1}, Phone Number: #{number1}, Address: #{address1}"
  end
end
