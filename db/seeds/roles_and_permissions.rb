# Idempotent seeder for the 4 roles and their DEFAULT per-resource permission
# matrix. Shared by: the BackfillUserRoles migration, db/seeds.rb, and the test
# support file. Safe to re-run — existing permissions are never overwritten, so
# admin customizations made through the role-manager UI are preserved.
module RolesAndPermissionsSeeder
  ROLES = {
    "admin" => "Administrador",
    "trial_center_branch_rep" => "Representante de Centro",
    "sponsor_rep" => "Representante de Patrocinador",
    "patient" => "Paciente"
  }.freeze

  # role => { "Resource" => [can_show, can_edit, can_delete] }.
  # admin is granted full access on every catalog resource separately (below).
  MATRIX = {
    "trial_center_branch_rep" => {
      "Patient" => [ true, true, false ],
      "Contact" => [ true, true, false ],
      "CriteriaProfile" => [ true, true, false ],
      "CriteriaVariable" => [ true, true, false ],
      "Result" => [ true, true, false ],
      "TrialCenterBranchRep" => [ true, true, false ],
      "Study" => [ true, false, false ],
      "TrialCenterBranch" => [ true, false, false ],
      "TrialCenterFacility" => [ true, false, false ],
      "TrialCity" => [ true, false, false ],
      "City" => [ true, false, false ],
      "Article" => [ true, false, false ],
      "Medication" => [ true, false, false ],
      "User" => [ true, false, false ]
    },
    "sponsor_rep" => {
      "Study" => [ true, true, false ],
      "Article" => [ true, true, false ],
      "Result" => [ true, true, false ],
      "Sponsor" => [ true, false, false ],
      "SponsorRep" => [ true, false, false ],
      "Medication" => [ true, false, false ],
      "User" => [ true, false, false ]
    },
    "patient" => {
      "Study" => [ true, false, false ],
      "Article" => [ true, false, false ],
      "Medication" => [ true, false, false ]
    }
  }.freeze

  def self.seed!
    ROLES.each do |name, display_name|
      role = Role.find_or_initialize_by(name: name)
      role.display_name = display_name
      role.save!
    end

    # Admin: full access across every managed resource.
    admin = Role.find_by!(name: "admin")
    PermissionCatalog::RESOURCES.each do |resource|
      grant(admin, resource, [ true, true, true ])
    end

    MATRIX.each do |role_name, resources|
      role = Role.find_by!(name: role_name)
      resources.each { |resource, flags| grant(role, resource, flags) }
    end
  end

  # Create the default permission only if absent; never clobber existing rows.
  def self.grant(role, resource, flags)
    can_show, can_edit, can_delete = flags
    role.role_permissions.find_or_create_by!(resource: resource) do |permission|
      permission.can_show = can_show
      permission.can_edit = can_edit
      permission.can_delete = can_delete
    end
  end
end
