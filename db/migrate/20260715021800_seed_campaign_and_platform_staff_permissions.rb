require Rails.root.join("db/seeds/roles_and_permissions")

# Adds the new "platform_staff" role and the Campaign / CampaignDocument grants
# to every environment on deploy (dev/prod via `db:migrate`; test seeds these in
# spec/support/roles.rb). Idempotent — RolesAndPermissionsSeeder.grant uses
# find_or_create_by! and never clobbers existing rows, mirroring how the original
# matrix was seeded by the BackfillUserRoles migration.
class SeedCampaignAndPlatformStaffPermissions < ActiveRecord::Migration[8.0]
  def up
    RolesAndPermissionsSeeder.seed!
  end

  def down
    # No-op: roles/permissions are not removed on rollback.
  end
end
