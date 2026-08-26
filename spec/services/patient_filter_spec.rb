require "rails_helper"

RSpec.describe PatientFilter do
  let(:city_a) { FactoryBot.create(:city) }
  let(:city_b) { FactoryBot.create(:city) }

  let(:branch_a) { FactoryBot.create(:trial_center_branch).tap { |b| b.cities << city_a } }
  let(:branch_b) { FactoryBot.create(:trial_center_branch).tap { |b| b.cities << city_b } }

  let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
  let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }

  let!(:interested_a) { FactoryBot.create(:patient, study: study_a, state: "interested", reported_city: "Bogotá") }
  let!(:candidate_a) { FactoryBot.create(:patient, study: study_a, state: "candidate", reported_city: "Medellín") }
  let!(:interested_b) { FactoryBot.create(:patient, study: study_b, state: "interested") }

  # No keyword arguments on purpose: with any declared, Ruby binds a bare
  # `"state" => "candidate"` at the call site to keywords instead of to the
  # positional hash these examples mean.
  def filter(params)
    described_class.new(Patient.recruiting, params, allowed_states: Patient::RECRUITING_STATES)
  end

  def filter_on(base, params)
    described_class.new(base, params, allowed_states: Patient::RECRUITING_STATES)
  end

  describe "narrowing" do
    it "returns everything in the base relation when nothing is asked for" do
      expect(filter({}).results).to contain_exactly(interested_a, candidate_a, interested_b)
    end

    it "filters by state" do
      expect(filter("state" => "candidate").results).to contain_exactly(candidate_a)
    end

    it "filters by study" do
      expect(filter("study_id" => study_a.id).results).to contain_exactly(interested_a, candidate_a)
    end

    it "filters by sponsor" do
      expect(filter("sponsor_id" => study_b.sponsor_id).results).to contain_exactly(interested_b)
    end

    it "filters by the city of the trial centre, reached through the branches" do
      expect(filter("city_id" => city_a.id).results).to contain_exactly(interested_a, candidate_a)
    end

    it "filters by trial centre branch" do
      expect(filter("trial_center_branch_id" => branch_b.id).results).to contain_exactly(interested_b)
    end

    it "filters by the city the patient reported for themselves" do
      expect(filter("reported_city" => "Medellín").results).to contain_exactly(candidate_a)
    end

    it "combines filters" do
      results = filter("study_id" => study_a.id, "state" => "interested").results

      expect(results).to contain_exactly(interested_a)
    end

    # A study running at several branches in one city used to multiply the
    # patient into one row per branch, which the fix for it (DISTINCT) then made
    # unorderable. Both filters are subqueries now, so neither can happen.
    it "returns one row per patient even when the study runs at several branches in the city" do
      extra = FactoryBot.create(:trial_center_branch).tap { |b| b.cities << city_a }
      study_a.trial_center_branches << extra

      expect(filter("city_id" => city_a.id).results.to_a.size).to eq(2)
    end
  end

  describe "the questionnaire filter" do
    before do
      FactoryBot.create(:patient_declaration, patient: candidate_a)
    end

    it "finds the patients who answered" do
      expect(filter("questionnaire" => "with").results).to contain_exactly(candidate_a)
    end

    it "finds the patients who did not, without losing anybody" do
      expect(filter("questionnaire" => "without").results).to contain_exactly(interested_a, interested_b)
    end
  end

  # A LEAD is what the public participation form produces: contact details and
  # nothing else, so no name. Worth isolating because a lead cannot be acted on
  # without a phone call — and because this is the one identity predicate that
  # survives encryption: it tests for NULL rather than comparing ciphertext,
  # which is why `Patient.leads` works where an ILIKE on a name cannot.
  describe "the leads filter" do
    let!(:lead) { FactoryBot.create(:patient, :lead, study: study_a, state: "candidate") }

    it "finds the patients who arrived with no name" do
      expect(filter("identity" => "lead").results).to contain_exactly(lead)
    end

    it "finds everybody else" do
      expect(filter("identity" => "named").results).to contain_exactly(interested_a, candidate_a, interested_b)
    end

    it "partitions the pipeline exactly — nobody is in neither half" do
      leads = filter("identity" => "lead").results.to_a
      named = filter("identity" => "named").results.to_a

      expect(leads + named).to match_array(Patient.recruiting.to_a)
      expect(leads & named).to be_empty
    end

    it "combines with the other filters" do
      expect(filter("identity" => "lead", "state" => "interested").results).to be_empty
      expect(filter("identity" => "lead", "state" => "candidate").results).to contain_exactly(lead)
    end

    # The public form leaves the column NULL, but the staff edit form submits
    # firstname="" on every save — so the first time a rep opens a lead and
    # presses save without typing a name, NULL becomes "". A nil-only test would
    # drop exactly the leads somebody has already touched once.
    it "still counts a lead whose name was blanked to an empty string by the edit form" do
      lead.update!(firstname: "", lastname: "")

      expect(filter("identity" => "lead").results).to include(lead)
      expect(filter("identity" => "named").results).not_to include(lead)
    end

    it "drops an identity value it does not recognise" do
      expect(filter("identity" => "anonymous").filters).not_to have_key(:identity)
    end

    it "knows when it is showing only leads, for the toggle's pressed state" do
      expect(filter("identity" => "lead").only_leads?).to be(true)
      expect(filter({}).only_leads?).to be(false)
    end

    # Counted against the base, not the filtered set: the badge answers "how many
    # leads are there to look at", which must not change as other filters narrow.
    it "counts the leads in the base relation, not in the filtered result" do
      expect(filter("study_id" => study_b.id).leads_count).to eq(1)
    end
  end

  # RULE 1: it only ever narrows. The relation it is handed has already been cut
  # down by PatientPolicy::Scope, so no query string can reach past it.
  describe "it can only narrow what it was given" do
    it "cannot reach a patient outside the base relation, even by asking for their study" do
      base = Patient.recruiting.where(study_id: study_a.id)

      expect(filter_on(base, "study_id" => study_b.id).results).to be_empty
    end

    it "cannot reach another sponsor's patients through the sponsor filter" do
      base = Patient.recruiting.for_sponsors(study_a.sponsor)

      expect(filter_on(base, "sponsor_id" => study_b.sponsor_id).results).to be_empty
    end
  end

  # The recruitment page and the participants page share this class; the state
  # bound is what stops either being talked into rendering the other's rows.
  describe "the state bound" do
    it "ignores a state the page does not allow" do
      filtered = filter("state" => "participant")

      expect(filtered.filters).not_to have_key(:state)
      expect(filtered.results.map(&:state).uniq).to match_array(%w[interested candidate])
    end

    it "accepts a state the page does allow" do
      FactoryBot.create(:patient, study: study_a, state: "participant")
      filtered = described_class.new(Patient.enrolled, { "state" => "participant" }, allowed_states: [ Patient::FINAL_STATE ])

      expect(filtered.filters[:state]).to eq("participant")
    end
  end

  describe "sloppy input" do
    it "treats a blank value as no filter at all" do
      expect(filter("study_id" => "", "state" => "").filters).to be_empty
    end

    it "drops an unknown questionnaire value rather than matching nothing" do
      expect(filter("questionnaire" => "maybe").filters).not_to have_key(:questionnaire)
    end

    it "ignores keys it does not recognise" do
      expect(filter("state" => "candidate", "sql" => "1=1").filters.keys).to eq([ :state ])
    end
  end

  # RULE 2: the options come from the scoped relation. A select listing another
  # sponsor's study would disclose that the study exists even though picking it
  # returns nothing — the option itself is the leak.
  describe "select options" do
    let(:scoped) { described_class.new(Patient.recruiting.where(study_id: study_a.id), {}, allowed_states: Patient::RECRUITING_STATES) }

    it "offers only the studies present in the scoped relation" do
      expect(scoped.studies).to contain_exactly(study_a)
    end

    it "offers only the sponsors of those studies" do
      expect(scoped.sponsors).to contain_exactly(study_a.sponsor)
    end

    it "offers only the cities those studies are run in" do
      expect(scoped.cities).to contain_exactly(city_a)
    end

    it "offers only the branches those studies run at" do
      expect(scoped.trial_center_branches).to contain_exactly(branch_a)
    end

    it "offers only the cities the visible patients reported" do
      expect(scoped.reported_cities).to contain_exactly("Bogotá", "Medellín")
    end
  end
end
