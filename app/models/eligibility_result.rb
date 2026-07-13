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

  def missing
    checks.select(&:missing?)
  end

  def failing
    checks.select { |c| c.status == :fail }
  end
end
