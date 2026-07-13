# Change-control (audit) view is admin-only *for now* — intentionally stricter
# than the per-resource `can_show` permission that ApplicationPolicy grants. When
# other roles should see the change log, widen this single method.
class ChangeControlPolicy < ApplicationPolicy
  def show?
    !!user&.admin?
  end
end
