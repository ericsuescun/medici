# frozen_string_literal: true

# Local parameters are platform configuration (what the local regulator is
# called, per country), so they are admin-only and deliberately NOT part of the
# Role permission matrix — same reasoning as RolePolicy.
class LocalParameterPolicy < ApplicationPolicy
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
