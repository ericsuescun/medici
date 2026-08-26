# Authorization is now enforced, and the User callback assigns a role from the
# userable type — so the 4 roles + default permission matrix must exist before
# any factory user is built. Seed them once for the whole suite (committed
# outside the per-example transaction, so they persist across examples).
require Rails.root.join("db/seeds/roles_and_permissions")

RSpec.configure do |config|
  config.before(:suite) do
    # Cleared first, on purpose. `RolesAndPermissionsSeeder.grant` uses
    # find_or_create_by! and deliberately NEVER clobbers an existing row — in
    # production an admin's customisations must survive a deploy. But the test
    # database keeps these rows between runs (they are committed outside the
    # per-example transaction), so without the delete a change to MATRIX would
    # never reach the suite: the specs would go on asserting an old matrix that
    # exists nowhere but that one database. Caught when the criteria permissions
    # moved from the centre to the sponsor on 2026-08-25.
    RolePermission.delete_all
    RolesAndPermissionsSeeder.seed!
  end
end
