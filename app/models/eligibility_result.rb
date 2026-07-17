# Outcome of evaluating a patient against a CriteriaProfile. Wraps a list of
# per-variable Checks and answers the two questions that matter: is the patient
# eligible, and is the assessment even complete (all values captured)?
class EligibilityResult
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

  # A single symbol summarizing the verdict, for banners/badges:
  #   :eligible     — every criterion answered and passing
  #   :not_eligible — at least one criterion measurably fails
  #   :incomplete   — nothing failing yet, but values still missing
  #   :empty        — no criteria to evaluate
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
end
