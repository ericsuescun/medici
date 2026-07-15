# frozen_string_literal: true

# Inherits generic CRUD (show?/edit?/destroy?/index? + Scope) from
# ApplicationPolicy, driven by the role permission matrix. Adds the bespoke
# AASM state-transition rules, which are gated by role *type* (admin or trial
# center rep) independently of the permission matrix.
class PatientPolicy < ApplicationPolicy
  # Patients are clinical records about identifiable people, so who may see WHICH
  # of them is not just a CRUD question. The permission matrix says whether a role
  # may see patients at all; this narrows it to the ones they have a reason to see.
  #
  # Before this, the inherited scope returned `scope.all` to anyone whose role had
  # can_show on Patient — so every trial centre rep could list every patient of
  # every study, including centres they have nothing to do with. That is the
  # restricted-access principle in the Research Notes (Resolución 1995 de 1999,
  # Art. 14), applied by analogy.
  class Scope < ApplicationPolicy::Scope
    def resolve
      visible = super # scope.all or scope.none, per the role's can_show
      return visible unless user&.trial_center_branch_rep?

      branch = user.userable&.trial_center_branch
      # A rep with no centre assigned has no patients to see — fail closed.
      return scope.none if branch.nil?

      visible.for_trial_center_branches(branch)
    end
  end

  # Whether a REP may touch THIS patient at all. Deliberately not expressed as
  # show?/update?/destroy? overrides: ResourceAuthorization authorizes the model
  # *class*, not the instance, so those overrides would silently never fire.
  # Row-level access is enforced by Scope above — PatientsController loads every
  # member action through `policy_scope`, so an out-of-reach patient 404s rather
  # than 403s, which also avoids confirming that the record exists.
  #
  # This predicate exists for the one thing a scope cannot cover: a rep must not
  # enrol a patient INTO a study that does not run at their centre.
  def enrol_into?(study)
    return false unless admin_or_trial_center_rep?
    return true if user.admin?

    branch = user.userable&.trial_center_branch
    return false if branch.nil?

    study.present? && study.trial_center_branches.include?(branch)
  end

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
