require 'rails_helper'

RSpec.describe RecruitmentProgress do
  def study_with(goal:, participants: 0, candidates: 0, prospects: 0)
    study = FactoryBot.create(:study, sample_size: goal)
    participants.times { FactoryBot.create(:patient, :participant, study: study) }
    candidates.times { FactoryBot.create(:patient, :candidate, study: study) }
    prospects.times { FactoryBot.create(:patient, study: study) }
    study
  end

  it "bulk-loads state counts and segment widths per study" do
    study = study_with(goal: 10, participants: 3, candidates: 2, prospects: 1)

    progress = described_class.for([ study ]).fetch(study.id)

    expect(progress).to be_renderable
    expect(progress.count(:participant)).to eq(3)
    expect(progress.count(:candidate)).to eq(2)
    expect(progress.count(:prospect)).to eq(1)
    expect(progress.total).to eq(6)
    expect(progress.percent(:participant)).to eq(30.0)
    expect(progress.percent(:candidate)).to eq(20.0)
    expect(progress.percent(:prospect)).to eq(10.0)
  end

  it "caps the stacked total at 100% when enrollment exceeds the goal" do
    study = study_with(goal: 4, participants: 3, candidates: 2, prospects: 2)

    progress = study.recruitment_progress

    expect(progress.percent(:participant)).to eq(75.0)
    expect(progress.percent(:candidate)).to eq(25.0)
    # Candidates already reached 100% — prospects get no width at all.
    expect(progress.percent(:prospect)).to eq(0.0)
  end

  it "is not renderable without a positive goal" do
    study = FactoryBot.create(:study, sample_size: nil)
    FactoryBot.create(:patient, :participant, study: study)

    expect(study.recruitment_progress).not_to be_renderable
  end
end
