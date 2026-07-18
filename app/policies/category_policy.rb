# frozen_string_literal: true

# Permission-matrix driven (see PermissionCatalog): only admins are granted
# Category access by the seeder, so the categories admin UI is admin-only.
class CategoryPolicy < ApplicationPolicy
end
