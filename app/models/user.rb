# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  firstname              :string
#  illness_description    :string           default("")
#  lastname               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  userable_type          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  role_id                :bigint
#  userable_id            :bigint
#
# Indexes
#
#  index_users_on_email                          (email) UNIQUE
#  index_users_on_reset_password_token           (reset_password_token) UNIQUE
#  index_users_on_role_id                        (role_id)
#  index_users_on_userable_type_and_userable_id  (userable_type,userable_id)
#
# Foreign Keys
#
#  fk_rails_...  (role_id => roles.id)
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable

  has_and_belongs_to_many :studies
  has_many :criteria_profiles, dependent: :destroy
  has_many :consents, dependent: :destroy
  belongs_to :role, optional: true

  # Virtual: the Ley 1581 habeas-data authorization checkbox on the sign-up form.
  # Enforced (and persisted as a Consent) in Users::RegistrationsController.
  attr_accessor :data_processing_authorization

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  delegated_type :userable, types: %w[SponsorRep Admin Patient TrialCenterBranchRep], dependent: :destroy

  # Authorization role is derived once from the userable (data) type at creation.
  # Every user-creation path sets `userable` before save, so this single callback
  # covers registration, the admins/reps controllers, and factories.
  ROLE_FOR_USERABLE = {
    "SponsorRep" => "sponsor_rep",
    "Admin" => "admin",
    "Patient" => "patient",
    "TrialCenterBranchRep" => "trial_center_branch_rep"
  }.freeze

  before_save :assign_default_role, if: -> { role_id.nil? && userable_type.present? }

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

  private

  def assign_default_role
    role_name = ROLE_FOR_USERABLE[userable_type]
    self.role = Role.find_by(name: role_name) if role_name
  end
end
