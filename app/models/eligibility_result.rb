# Outcome of evaluating a patient against a CriteriaProfile. Wraps a list of
# per-variable Checks and answers two kinds of question: does the patient meet
# the protocol, and may they move along the recruitment lifecycle.
#
# The protocol question (`eligible?`, `complete?`, `verdict`) weighs every
# criterion, because a patient who fails any criterion does not meet the
# protocol.
#
# The lifecycle question is asked TWICE, once per tier, because the two steps
# are different claims (see CriteriaVariable#criteria_category):
#
#   basic     — the decisive few a patient can answer about themselves. They
#               carry `basic_score` and open interested → candidate.
#   specific  — the investigator-measured rest. They carry `specific_score` and,
#               together with the basic tier, open candidate → potential.
#
# The protocol verdict and the tier verdicts are allowed to disagree, and the UI
# surfaces both rather than collapsing them: `verdict` is kept for reporting,
# `basic_verdict` is what the banner headlines, and the specific tier is shown
# as its own gate with its own count.
class EligibilityResult
  # A patient is recommended for promotion only when every basic criterion is
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

    # Which tier this criterion belongs to — which lifecycle step it gates.
    def basic?
      variable.criteria_category == "basic"
    end

    def specific?
      !basic?
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
  # criterion regardless of tier:
  #   :eligible     — every criterion answered and passing
  #   :not_eligible — at least one criterion measurably fails
  #   :incomplete   — nothing failing yet, but values still missing
  #   :empty        — no criteria to evaluate
  #
  # This is the honest "does the patient meet the protocol" answer, kept for
  # reporting. It is deliberately NOT what the UI headlines: a patient who has
  # simply not been measured yet should not be shouted at as "not eligible".
  # Use `basic_verdict` for the headline and `specific_verdict` beside it.
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

  # ---- Basic tier (interested → candidate) ---------------------------------

  def basic_checks
    checks.select(&:basic?)
  end

  def basic_passing
    basic_checks.select { |c| c.status == :pass }
  end

  def basic_failing
    basic_checks.select { |c| c.status == :fail }
  end

  def basic_pending
    basic_checks.select(&:missing?)
  end

  # Percentage (0–100) of the decisive criteria the patient satisfies, measured
  # against *all* basic criteria rather than only the answered ones: an
  # unmeasured criterion is not evidence in the patient's favour, so it should
  # hold the score down until somebody measures it. nil when the profile defines
  # no basic criteria at all (nothing to score).
  def basic_score
    return nil if basic_checks.none?

    (basic_passing.count.to_f / basic_checks.count * 100).round
  end

  def basic_answered_count
    basic_checks.count { |c| !c.missing? }
  end

  def basic_total_count
    basic_checks.size
  end

  # What the basic score says a rep should do:
  #   :ready     — every basic criterion answered and passing; promote
  #   :promising — nothing decisive failed and the score is already high; worth
  #                a look, finish measuring the rest
  #   :blocked   — a decisive criterion measurably fails; do not promote on
  #                criteria grounds, whatever the rest of the score says
  #   :pending   — too little measured yet to say anything
  #   :none      — the profile marks no criterion basic, so there is no score
  def recommendation
    return :none if basic_checks.none?
    return :blocked if basic_failing.any?
    return :ready if basic_score >= READY_SCORE
    return :promising if basic_score >= HIGH_SCORE

    :pending
  end

  # The eligibility verdict as the UI headlines it: decided by the basic
  # criteria alone.
  #   :eligible     — every basic criterion is recorded AND complies
  #   :not_eligible — at least one basic criterion measurably fails
  #   :incomplete   — none failing, but basic criteria are still unrecorded
  #   :none         — the profile marks nothing basic; nothing decisive to say
  #
  # Note what :eligible means for an exclusion criterion: it complies when the
  # patient does NOT meet it. An unrecorded exclusion never counts as complying,
  # so "no active infection" is only ever true because somebody measured it.
  def basic_verdict
    return :none if basic_checks.none?
    return :not_eligible if basic_failing.any?
    return :incomplete if basic_pending.any?

    :eligible
  end

  # Tier 1 gate: every basic criterion recorded and complying — or no basic
  # criteria at all, in which case there is nothing decisive to hold anyone
  # back. Authority behind Patient's AASM guard on `assess`.
  def basic_criteria_met?
    %i[none eligible].include?(basic_verdict)
  end

  # ---- Specific tier (candidate → potential) -------------------------------

  def specific_checks
    checks.select(&:specific?)
  end

  def specific_passing
    specific_checks.select { |c| c.status == :pass }
  end

  def specific_failing
    specific_checks.select { |c| c.status == :fail }
  end

  def specific_pending
    specific_checks.select(&:missing?)
  end

  # How many specific criteria the patient meets. A COUNT, not a percentage, on
  # purpose: this is what the patient list sorts by, and a rep comparing two
  # candidates wants "5 of 7" rather than "71%" — the denominator differs per
  # study, so the raw count is the honest comparison within one study's queue.
  # 0 when the profile defines none.
  def specific_score
    specific_passing.count
  end

  def specific_answered_count
    specific_checks.count { |c| !c.missing? }
  end

  def specific_total_count
    specific_checks.size
  end

  # Mirrors `basic_verdict` so the UI can render the two tiers alike:
  #   :met        — every specific criterion recorded and complying
  #   :not_met    — at least one measurably fails
  #   :incomplete — none failing, but some still unrecorded
  #   :none       — the profile marks nothing specific
  def specific_verdict
    return :none if specific_checks.none?
    return :not_met if specific_failing.any?
    return :incomplete if specific_pending.any?

    :met
  end

  # Tier 2 gate, specific half: every specific criterion recorded and complying.
  # Vacuously true when the profile defines none — with nothing to check there
  # is nothing to block on, the same fail-open the basic tier has. What keeps a
  # self-reported patient out of `potential` is the BASIC half of the tier-2
  # guard requiring investigator values, not this one.
  def specific_criteria_met?
    %i[none met].include?(specific_verdict)
  end

  # ---- Cross-tier -----------------------------------------------------------

  # The score endorses moving this patient forward on the basic tier. Narrower
  # than `basic_criteria_met?`: this is false when there are no basic criteria,
  # because there is no score to endorse anything with.
  def promotable?
    recommendation == :ready
  end

  # Worth surfacing to a rep even if not yet promotable.
  def high_score?
    %i[ready promising].include?(recommendation)
  end
end
