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
  has_many :criteria_profiles, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  delegated_type :userable, types: %w[SponsorRep Admin Patient TrialCenterBranchRep], dependent: :destroy

  delegate :dob,
           :sex,
           :contact_number,
           :contact_address,
           :notes,
           :country,
           :illness_description,
           :id_type,
           :id_number,
           :state, to: :userable, allow_nil: true

  accepts_nested_attributes_for :userable

  # Scopes based on delegated type
  scope :patients, -> { where(userable_type: "Patient") }
  scope :sponsors, -> { where(userable_type: "SponsorRep") }
  scope :admins,   -> { where(userable_type: "Admin") }
  scope :trial_center_branch_reps, -> { where(userable_type: "TrialCenterBranchRep") }

  # Convenience predicate methods to keep API compatible with previous enum
  def patient?
    userable_type == "Patient"
  end

  def sponsor?
    userable_type == "SponsorRep"
  end

  def admin?
    userable_type == "Admin"
  end

  def trial_center_branch_rep?
    userable_type == "TrialCenterBranchRep"
  end

  def fullname
    return "" if firstname.blank? || lastname.blank?

    firstname + " " + lastname
  end
end
