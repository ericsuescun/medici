require 'rails_helper'

# Exercised through CriteriaVariable; unsaved instances are enough for the
# atomic comparison logic.
RSpec.describe CriteriaComparable do
  def var(attrs)
    CriteriaVariable.new(attrs)
  end

  describe "#satisfied_by?" do
    it "returns nil for a blank value" do
      v = var(value_type: "quantitative", comparison_type: "more_than", reference_value_1: 5)
      expect(v.satisfied_by?(nil)).to be_nil
      expect(v.satisfied_by?("")).to be_nil
    end

    context "quantitative" do
      it "handles between_range inclusively" do
        v = var(value_type: "quantitative", comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40)
        expect(v.satisfied_by?(25)).to be(true)
        expect(v.satisfied_by?(18)).to be(true)
        expect(v.satisfied_by?(40)).to be(true)
        expect(v.satisfied_by?(41)).to be(false)
        expect(v.satisfied_by?(17)).to be(false)
      end

      it "handles the ordering + equality operators" do
        expect(var(value_type: "quantitative", comparison_type: "more_than_or_equal", reference_value_1: 20).satisfied_by?(20)).to be(true)
        expect(var(value_type: "quantitative", comparison_type: "more_than_or_equal", reference_value_1: 20).satisfied_by?(19)).to be(false)
        expect(var(value_type: "quantitative", comparison_type: "more_than", reference_value_1: 20).satisfied_by?(20)).to be(false)
        expect(var(value_type: "quantitative", comparison_type: "less_than", reference_value_1: 10).satisfied_by?(9)).to be(true)
        expect(var(value_type: "quantitative", comparison_type: "out_of_range", reference_value_1: 18, reference_value_2: 40).satisfied_by?(50)).to be(true)
        expect(var(value_type: "quantitative", comparison_type: "equal", reference_value_1: 5).satisfied_by?("5")).to be(true)
        expect(var(value_type: "quantitative", comparison_type: "different", reference_value_1: 5).satisfied_by?(6)).to be(true)
      end

      it "returns nil when the value is not numeric" do
        expect(var(value_type: "quantitative", comparison_type: "more_than", reference_value_1: 5).satisfied_by?("abc")).to be_nil
      end
    end

    context "boolean" do
      it "handles true/false (and truthy strings)" do
        expect(var(value_type: "boolean", comparison_type: "true").satisfied_by?(true)).to be(true)
        expect(var(value_type: "boolean", comparison_type: "true").satisfied_by?("1")).to be(true)
        expect(var(value_type: "boolean", comparison_type: "true").satisfied_by?(false)).to be(false)
        expect(var(value_type: "boolean", comparison_type: "false").satisfied_by?(false)).to be(true)
      end
    end

    context "qualitative" do
      it "handles equal/different case-insensitively" do
        v = var(value_type: "qualitative", comparison_type: "equal", qualitative_value: "grave")
        expect(v.satisfied_by?("grave")).to be(true)
        expect(v.satisfied_by?("Grave")).to be(true)
        expect(v.satisfied_by?("leve")).to be(false)
        expect(var(value_type: "qualitative", comparison_type: "different", qualitative_value: "grave").satisfied_by?("leve")).to be(true)
      end
    end
  end
end
