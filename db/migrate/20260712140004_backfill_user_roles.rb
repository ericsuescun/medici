class BackfillUserRoles < ActiveRecord::Migration[8.0]
  # userable_type (the delegated_type discriminator) -> role name
  ROLE_FOR_USERABLE = {
    "Admin" => "admin",
    "Patient" => "patient",
    "SponsorRep" => "sponsor_rep",
    "TrialCenterBranchRep" => "trial_center_branch_rep"
  }.freeze

  def up
    # Ensure the roles and the default permission matrix exist (idempotent).
    require Rails.root.join("db/seeds/roles_and_permissions").to_s
    RolesAndPermissionsSeeder.seed!

    role_ids = Role.pluck(:name, :id).to_h

    # Use a migration-local, bare AR class (not the app User) so Devise modules
    # and the User -> userable delegation don't run during a bulk update.
    users = Class.new(ActiveRecord::Base) { self.table_name = "users" }

    ROLE_FOR_USERABLE.each do |userable_type, role_name|
      role_id = role_ids[role_name] or next
      users.where(userable_type: userable_type, role_id: nil).update_all(role_id: role_id)
    end
  end

  def down
    Class.new(ActiveRecord::Base) { self.table_name = "users" }.update_all(role_id: nil)
  end
end
