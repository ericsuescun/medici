# Outcome of evaluating a patient against a CriteriaProfile. Wraps a list of
# per-variable Checks and answers three questions: is the patient eligible, is
# the assessment even complete (all values captured), and — the recruitment
# question — is there enough evidence to move the patient forward.
#
# The first two are about the *protocol*: they weigh every criterion, because a
# patient who fails any criterion does not meet the protocol. The third is about
# *recruitment*, and only weighs the criteria marked primary (see
# CriteriaVariable#criteria_category): those carry the score that tells a rep
# whether an interested patient is ready to become a candidate. Secondary
# criteria are still measured and still shown — they complement the picture —
# but they never move the score, so they can never on their own promote or hold
# back a patient.
#
# The two can therefore disagree, and that is the point: a patient can be
# `:ready` on the decisive criteria while a complementary criterion is still not
# met. Surface both rather than collapsing them.
class EligibilityResult
  # A patient is recommended for promotion only when every primary criterion is
  # answered and passing — a decisive criterion left unmeasured is not evidence.
  READY_SCORE = 100
  # Below `ready` but at or above this, the score is worth a rep's attention:
  # nothing decisive has failed and most of it already passes.
  HIGH_SCORE = 70

  # One variable's outcome. `met` is true/false/nil (nil = the patient has no
  # value for it yet). Passing depends on polarity:
  #   inclusion -> the patient must meet it (met == true)
  #   exclusion -> the patient must NOT meet it (met == false); an unmeasured
  #                exclusion (nil) does not pass, so it surfaces as incomplete.
  Check = Struct.new(:variable, :value, :met, keyword_init: true) do
    def passed?
      case variable.variable_type
      when "inclusion" then met == true
      when "exclusion" then met == false
      else false
      end
    end

    def missing?
      met.nil?
    end

    def status
      return :missing if missing?

      passed? ? :pass : :fail
    end

    # Decisive (scored) vs complementary (informative only).
    def primary?
      variable.criteria_category == "primary"
    end

    def secondary?
      !primary?
    end
  end

  attr_reader :checks

  def initialize(checks)
    @checks = checks
  end

  # Eligible only when every variable is answered AND passes.
  def eligible?
    checks.any? && checks.all?(&:passed?)
  end

  # Every variable has a captured value (nothing left to assess).
  def complete?
    checks.none?(&:missing?)
  end

  # Criteria the patient satisfies.
  def passing
    checks.select { |c| c.status == :pass }
  end

  # Criteria still to be measured ("pending"). Alias kept for the brief's vocabulary.
  def missing
    checks.select(&:missing?)
  end
  alias_method :pending, :missing

  # Criteria the patient measurably does NOT meet ("out of reach").
  def failing
    checks.select { |c| c.status == :fail }
  end

  # A single symbol summarizing the WHOLE-PROTOCOL verdict, weighing every
  # criterion regardless of category:
  #   :eligible     — every criterion answered and passing
  #   :not_eligible — at least one criterion measurably fails
  #   :incomplete   — nothing failing yet, but values still missing
  #   :empty        — no criteria to evaluate
  #
  # This is the honest "does the patient meet the protocol" answer, kept for
  # reporting. It is deliberately NOT what the UI headlines any more: a patient
  # blocked only by a complementary criterion should not be shouted at as "not
  # eligible". Use `primary_verdict` for that, plus `secondary_concerns` as a
  # separate advisory. See EligibilityResult#primary_verdict.
  def verdict
    return :empty if checks.none?
    return :eligible if eligible?
    return :not_eligible if failing.any?

    :incomplete
  end

  # Count of criteria answered so far, out of the total — for a progress read.
  def answered_count
    checks.count { |c| !c.missing? }
  end

  def total_count
    checks.size
  end

  # ---- Recruitment score (primary criteria only) ---------------------------

  def primary_checks
    checks.select(&:primary?)
  end

  def secondary_checks
    checks.select(&:secondary?)
  end

  def primary_passing
    primary_checks.select { |c| c.status == :pass }
  end

  def primary_failing
    primary_checks.select { |c| c.status == :fail }
  end

  def primary_pending
    primary_checks.select(&:missing?)
  end

  # Percentage (0–100) of the decisive criteria the patient satisfies, measured
  # against *all* primary criteria rather than only the answered ones: an
  # unmeasured criterion is not evidence in the patient's favour, so it should
  # hold the score down until somebody measures it. nil when the profile defines
  # no primary criteria at all (nothing to score).
  def primary_score
    return nil if primary_checks.none?

    (primary_passing.count.to_f / primary_checks.count * 100).round
  end

  def primary_answered_count
    primary_checks.count { |c| !c.missing? }
  end

  def primary_total_count
    primary_checks.size
  end

  # What the score says a rep should do:
  #   :ready     — every primary criterion answered and passing; promote
  #   :promising — nothing decisive failed and the score is already high; worth
  #                a look, finish measuring the rest
  #   :blocked   — a decisive criterion measurably fails; do not promote on
  #                criteria grounds, whatever the rest of the score says
  #   :pending   — too little measured yet to say anything
  #   :none      — the profile marks no criterion primary, so there is no score
  def recommendation
    return :none if primary_checks.none?
    return :blocked if primary_failing.any?
    return :ready if primary_score >= READY_SCORE
    return :promising if primary_score >= HIGH_SCORE

    :pending
  end

  # The eligibility verdict as the UI headlines it: decided by the primary
  # criteria alone.
  #   :eligible     — every primary criterion is recorded AND complies
  #   :not_eligible — at least one primary criterion measurably fails
  #   :incomplete   — none failing, but primary criteria are still unrecorded
  #   :none         — the profile marks nothing primary; nothing decisive to say
  #
  # Note what :eligible means for an exclusion criterion: it complies when the
  # patient does NOT meet it. An unrecorded exclusion never counts as complying,
  # so "no active infection" is only ever true because somebody measured it.
  def primary_verdict
    return :none if primary_checks.none?
    return :not_eligible if primary_failing.any?
    return :incomplete if primary_pending.any?

    :eligible
  end

  # Whether the criteria allow this patient to move forward in the trial.
  #
  # True only when every primary criterion has a recorded value and all of them
  # comply — or when the profile defines no primary criteria at all, in which
  # case there is nothing decisive to hold anyone back. Secondary criteria are
  # never consulted: whether an unmet complementary criterion matters is the
  # rep's judgment, and the rep expresses it by making (or not making) the
  # transition, which PaperTrail records.
  #
  # This is the authority behind Patient's AASM guard on assess/accept.
  def permits_promotion?
    %i[none eligible].include?(primary_verdict)
  end

  # The score endorses moving this patient forward. Narrower than
  # `permits_promotion?`: this is false when there are no primary criteria,
  # because there is no score to endorse anything with.
  def promotable?
    recommendation == :ready
  end

  # Worth surfacing to a rep even if not yet promotable.
  def high_score?
    %i[ready promising].include?(recommendation)
  end

  # Complementary criteria the patient does not meet. These do NOT block
  # promotion — they are shown so the decision is made with eyes open.
  def secondary_concerns
    secondary_checks.select { |c| c.status == :fail }
  end
end
