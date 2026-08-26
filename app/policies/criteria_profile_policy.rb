# frozen_string_literal: true

class CriteriaProfilePolicy < ApplicationPolicy
  # WHOSE criteria a role may reach (added 2026-08-25, when the profile moved
  # from the trial centre to the sponsor).
  #
  # This is not optional decoration on that permission change. The matrix is
  # class-level — it answers "may this role touch criteria profiles at all" —
  # and `authorize` never restricts WHICH rows a permitted role sees; that
  # always needs a Scope (the standing lesson from the 2026-07-11 audit). Without
  # one, granting sponsor reps `can_edit` would let any sponsor rep rewrite ANY
  # sponsor's criteria. Those criteria gate promotion, so that is a forgeable
  # eligibility gate, not merely a disclosure — the same escalation
  # CriteriaAssessmentsController had until 2026-07-31.
  #
  # It replaces a creator-ownership filter (`where(user: current_user)`) that the
  # two controllers hand-rolled. Creator ownership is also why the permission
  # change needed this: every seeded profile is owned by an admin, so a sponsor
  # rep would have reached NONE of their own studies' criteria — "the sponsor
  # owns the profile" has to mean the sponsor's ORGANISATION, not whoever
  # happened to type it in, or a profile is orphaned the day that person leaves.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.nil?

      visible = super # scope.all or scope.none, per the role's can_show
      return visible if user.admin?

      if user.sponsor?
        sponsor = user.userable&.sponsor
        return scope.none if sponsor.nil?

        return for_studies(visible, Study.where(sponsor_id: sponsor).select(:id))
      end

      if user.trial_center_branch_rep?
        branch = user.userable&.trial_center_branch
        return scope.none if branch.nil?

        return for_studies(visible, Study.joins(:trial_center_branches)
                                         .where(trial_center_branches: { id: branch })
                                         .select(:id))
      end

      scope.none
    end

    private

    # The profiles of `study_ids`, plus this user's own unattached templates.
    # `study_id: nil` profiles are reusable templates (allowed by the model, and
    # by the partial unique index which only covers `study_id IS NOT NULL`);
    # they belong to nobody's study, so creator ownership is the only sensible
    # rule left for them.
    def for_studies(visible, study_ids)
      visible.where(study_id: study_ids).or(visible.where(study_id: nil, user_id: user.id))
    end
  end
end
