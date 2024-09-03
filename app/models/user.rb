# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  contact_address        :string           default("")
#  contact_number         :string           default("")
#  dob                    :date
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  firstname              :string           default("")
#  id_number              :string           default("")
#  id_type                :string           default("")
#  lastname               :string           default("")
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  user_type              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable

  has_and_belongs_to_many :studies

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :user_type, sponsor: 'sponsor', admin: 'admin', patient: 'patient'

  scope :patients, -> { where(user_type: 'patient') }
  scope :sponsors, -> { where(user_type: 'sponsor') }
  scope :admins, -> { where(user_type: 'admin') }

  def fullname
    firstname + ' ' + lastname
  end
end
