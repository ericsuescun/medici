# Shared comparison logic for the eligibility rules. Both CriteriaVariable (the
# rule) and VariableValue (the patient's snapshot) carry the same comparison
# columns (value_type, comparison_type, reference_value_1/2, qualitative_value),
# so the atomic "does this value meet the comparison?" logic lives here once.
#
# `satisfied_by?` is polarity-agnostic — inclusion/exclusion interpretation
# happens in CriteriaProfile#evaluate. It returns nil when the value is blank or
# can't be evaluated (so the caller can distinguish "unknown" from true/false).
module CriteriaComparable
  extend ActiveSupport::Concern

  def satisfied_by?(raw)
    return nil if raw.nil? || raw.to_s.strip.empty?

    case value_type
    when "boolean"      then boolean_satisfied?(raw)
    when "quantitative" then quantitative_satisfied?(raw)
    when "qualitative"  then qualitative_satisfied?(raw)
    end
  end

  # Short human description of the comparison, e.g. "entre 18 y 40", "≥ 20", "Sí".
  def rule_summary
    case value_type
    when "boolean"      then comparison_type == "true" ? "Sí" : "No"
    when "qualitative"  then "#{comparison_type == 'different' ? '≠' : '='} #{qualitative_value}"
    when "quantitative"
      r1 = fmt_reference(reference_value_1)
      r2 = fmt_reference(reference_value_2)
      case comparison_type
      when "between_range"      then "entre #{r1} y #{r2}"
      when "out_of_range"       then "fuera de #{r1}–#{r2}"
      when "less_than"          then "< #{r1}"
      when "less_than_or_equal" then "≤ #{r1}"
      when "more_than"          then "> #{r1}"
      when "more_than_or_equal" then "≥ #{r1}"
      when "equal"              then "= #{r1}"
      when "different"          then "≠ #{r1}"
      end
    end
  end

  private

  def fmt_reference(value)
    return if value.nil?

    number = value.to_f
    (number % 1).zero? ? number.to_i.to_s : number.to_s
  end

  def boolean_satisfied?(raw)
    actual = ActiveModel::Type::Boolean.new.cast(raw)
    case comparison_type
    when "true"  then actual == true
    when "false" then actual == false
    end
  end

  def quantitative_satisfied?(raw)
    actual = Float(raw, exception: false)
    return nil if actual.nil?

    ref1 = reference_value_1&.to_f
    ref2 = reference_value_2&.to_f

    case comparison_type
    when "less_than"          then ref1 && actual < ref1
    when "less_than_or_equal" then ref1 && actual <= ref1
    when "more_than"          then ref1 && actual > ref1
    when "more_than_or_equal" then ref1 && actual >= ref1
    when "between_range"      then ref1 && ref2 && actual.between?(ref1, ref2)
    when "out_of_range"       then ref1 && ref2 && !actual.between?(ref1, ref2)
    when "equal"              then ref1 && actual == ref1
    when "different"          then ref1 && actual != ref1
    end
  end

  def qualitative_satisfied?(raw)
    expected = qualitative_value.to_s.strip
    actual = raw.to_s.strip

    case comparison_type
    when "equal"     then actual.casecmp?(expected)
    when "different" then !actual.casecmp?(expected)
    end
  end
end
