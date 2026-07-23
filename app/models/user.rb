# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(FALSE), not null
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
#  index_users_on_active                         (active)
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

  # NOT :registerable — nobody self-registers. Patients no longer have accounts
  # at all (they are records created from the public participation form or by a
  # centre rep); staff accounts are created by an admin through the role-specific
  # controllers. Dropping the module also removes the sign-up routes and makes
  # `devise_mapping.registerable?` false, which hides the "Registrarse" links.
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  delegated_type :userable, types: %w[SponsorRep Admin Patient TrialCenterBranchRep PlatformStaff], dependent: :destroy

  # Authorization role is derived once from the userable (data) type at creation.
  # Every user-creation path sets `userable` before save, so this single callback
  # covers registration, the admins/reps controllers, and factories.
  ROLE_FOR_USERABLE = {
    "SponsorRep" => "sponsor_rep",
    "Admin" => "admin",
    "Patient" => "patient",
    "TrialCenterBranchRep" => "trial_center_branch_rep",
    "PlatformStaff" => "platform_staff"
  }.freeze

  before_save :assign_default_role, if: -> { role_id.nil? && userable_type.present? }

  # Admins are always active — the activation manager is theirs to operate, so
  # locking the last admin out of it would be unrecoverable. Runs on every save
  # (like assign_default_role) because `userable` is only assigned right before
  # the insert on the nested-attributes creation paths.
  before_save :force_active_for_admins, if: -> { userable_type == "Admin" }

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
  scope :platform_staffs, -> { where(userable_type: "PlatformStaff") }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Devise checks this at sign-in AND on every request (Devise::Hooks::Activatable),
  # so deactivating an account also terminates the session it is already using.
  # Admins pass regardless: force_active_for_admins already keeps their column
  # true, and the belt-and-braces carve-out means no direct DB write can lock
  # the people who operate the activation manager out of it.
  def active_for_authentication?
    super && (active? || admin?)
  end

  # Message shown when the sign-in is refused above (devise.failure.inactive).
  def inactive_message
    active_for_authentication? ? super : :inactive
  end

  # Whose account this is, organisationally — the sponsor for a sponsor rep, the
  # trial centre branch for a branch rep. Nil for admins/platform staff, who
  # belong to no external organisation. Used by the activation manager.
  def organization_name
    case userable
    when SponsorRep then userable.sponsor&.name
    when TrialCenterBranchRep then userable.trial_center_branch&.name
    end
  end

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

  def platform_staff?
    userable_type == "PlatformStaff"
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

  def force_active_for_admins
    self.active = true
  end
end
