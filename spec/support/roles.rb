# Authorization is now enforced, and the User callback assigns a role from the
# userable type — so the 4 roles + default permission matrix must exist before
# any factory user is built. Seed them once for the whole suite (committed
# outside the per-example transaction, so they persist across examples).
require Rails.root.join("db/seeds/roles_and_permissions")

RSpec.configure do |config|
  config.before(:suite) do
    RolesAndPermissionsSeeder.seed!
  end
end
