# frozen_string_literal: true

# Inherits generic CRUD (show?/edit?/destroy?/index? + Scope) from
# ApplicationPolicy, driven by the role permission matrix. Adds the bespoke
# AASM state-transition rules, which are gated by role *type* (admin or trial
# center rep) independently of the permission matrix.
class PatientPolicy < ApplicationPolicy
  # Only admins and trial center reps can view the state value
  def show_state?
    admin_or_trial_center_rep?
  end

  alias_method :view_state?, :show_state?

  # Only admins and trial center reps can change the state value
  def update_state?
    admin_or_trial_center_rep?
  end

  # Guarded state transition permissions leveraging AASM may_*? checks
  def assess?
    admin_or_trial_center_rep? && record.may_assess?
  end

  def accept?
    admin_or_trial_center_rep? && record.may_accept?
  end

  def discard?
    admin_or_trial_center_rep? && record.may_discard?
  end

  def reject?
    admin_or_trial_center_rep? && record.may_reject?
  end

  private

  def admin_or_trial_center_rep?
    return false if user.nil?

    user.admin? || user.trial_center_branch_rep?
  end
end
