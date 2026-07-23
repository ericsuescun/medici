# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Activating/deactivating accounts is admin-only and deliberately NOT driven by
  # the permission matrix — same reasoning as RolePolicy: a role able to grant
  # itself sign-in access to other accounts is a privilege-escalation path.
  def manage_activation?
    !!user&.admin?
  end
end
