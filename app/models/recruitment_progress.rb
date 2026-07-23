# Recruitment progress of a study toward its goal (its sample size): how many
# patients sit in each AASM lifecycle state, expressed as stacked-bar segment
# widths. Segments fill in seniority order — participants, then candidates,
# then interested — and the stacked total is capped at 100% so an over-enrolled
# study can't overflow the bar; the white remainder is the unmet goal.
#
# Use .for(studies) to bulk-load a whole listing with ONE grouped query.
class RecruitmentProgress
  STATES = %w[participant candidate interested].freeze

  attr_reader :goal

  def self.for(studies)
    studies = Array(studies)
    grouped = Patient.where(study_id: studies.map(&:id)).group(:study_id, :state).count

    studies.to_h do |study|
      counts = STATES.index_with { |state| grouped.fetch([ study.id, state ], 0) }
      [ study.id, new(goal: study.recruitment_goal, counts: counts) ]
    end
  end

  def initialize(goal:, counts:)
    @goal = goal.to_i
    @counts = counts
  end

  # Without a positive goal there is no 100% to measure against.
  def renderable?
    goal.positive?
  end

  def count(state)
    @counts.fetch(state.to_s, 0)
  end

  def total
    STATES.sum { |state| count(state) }
  end

  # Patients still wanted to reach the goal (never negative).
  def missing
    [ goal - total, 0 ].max
  end

  # Width of the white (unfilled) region after all state segments.
  def remainder_percent
    (100.0 - segments.values.sum).round(1).clamp(0.0, 100.0)
  end

  # Segment width (0.0..100.0) for one state, after the states before it in
  # STATES order have claimed their share of the bar.
  def percent(state)
    segments.fetch(state.to_s, 0.0)
  end

  private

  def segments
    @segments ||= begin
      remaining = 100.0
      STATES.index_with do |state|
        raw = renderable? ? (count(state) * 100.0 / goal) : 0.0
        width = [ raw, remaining ].min.round(1)
        remaining = (remaining - width).round(1)
        width
      end
    end
  end
end
