# frozen_string_literal: true

# The role-manager itself is admin-only (Role is deliberately NOT in the
# permission matrix — managing permissions must not be self-grantable).
class RolePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end

  private

  def admin?
    !!user&.admin?
  end
end
