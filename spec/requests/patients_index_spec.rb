require "rails_helper"

# The recruitment index and the potentials page, end to end: what each one is
# for, and — the part that matters most — who is allowed to appear on them.
#
# Rows are matched by dom_id rather than by name: a patient who arrived through
# the public form has no name at all, and the name column is encrypted.
RSpec.describe "Patients index and potentials", type: :request do
  let(:city) { FactoryBot.create(:city) }
  let(:branch_a) { FactoryBot.create(:trial_center_branch).tap { |b| b.cities << city } }
  let(:branch_b) { FactoryBot.create(:trial_center_branch) }

  let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
  let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }

  let!(:interested_a) { FactoryBot.create(:patient, study: study_a, state: "interested") }
  let!(:candidate_a) { FactoryBot.create(:patient, study: study_a, state: "candidate") }
  let!(:potential_a) { FactoryBot.create(:patient, study: study_a, state: "potential") }
  let!(:interested_b) { FactoryBot.create(:patient, study: study_b, state: "interested") }

  def row?(patient)
    response.body.include?(%(id="#{ActionView::RecordIdentifier.dom_id(patient)}"))
  end

  def grant_patient_show!(role_name)
    role = Role.find_by!(name: role_name)
    role.role_permissions.find_or_initialize_by(resource: "Patient").update!(can_show: true)
  end

  describe "GET /patients — the recruitment pipeline" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists the patients that are still work" do
      get patients_path

      expect(response).to be_successful
      expect(row?(interested_a)).to be(true)
      expect(row?(candidate_a)).to be(true)
    end

    # Enrolled patients are a result, not a queue. Leaving them here grew the
    # page a rep opens all day by one permanently-irrelevant row per success.
    it "leaves the enrolled ones out" do
      get patients_path

      expect(row?(potential_a)).to be(false)
    end

    it "cannot be talked into showing an enrolled patient through the state filter" do
      get patients_path, params: { state: "potential" }

      expect(response).to be_successful
      expect(row?(potential_a)).to be(false)
      expect(row?(candidate_a)).to be(true)
    end

    it "orders candidates before interested — they asked for the rep's attention" do
      get patients_path

      expect(response.body.index(ActionView::RecordIdentifier.dom_id(candidate_a)))
        .to be < response.body.index(ActionView::RecordIdentifier.dom_id(interested_a))
    end

    it "narrows to one study when asked" do
      get patients_path, params: { study_id: study_a.id }

      expect(row?(interested_a)).to be(true)
      expect(row?(interested_b)).to be(false)
    end

    it "narrows by the city of the trial centre" do
      get patients_path, params: { city_id: city.id }

      expect(row?(candidate_a)).to be(true)
      expect(row?(interested_b)).to be(false)
    end

    it "narrows by recruitment recommendation" do
      # No criteria profile means no recommendation, so asking for one that
      # nothing can satisfy must empty the page rather than ignore the filter.
      get patients_path, params: { recommendation: "ready" }

      expect(row?(interested_a)).to be(false)
      expect(response.body).to include(I18n.t("patients.no_matches"))
    end
  end

  # The case the recruitment page exists for: somebody who pressed "¡Quiero
  # participar!", left a phone number and nothing else, answered the public
  # questionnaire, and was auto-triaged to candidate. No name, so they are easy
  # to skim past — and nothing can happen until a rep rings them.
  describe "leads — patients the public form created" do
    let!(:lead) { FactoryBot.create(:patient, :lead, study: study_a, state: "candidate", contact_number: "+57 300 111 2222") }

    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists a nameless lead under their participant code rather than an empty cell" do
      get patients_path

      expect(row?(lead)).to be(true)
      expect(response.body).to include(lead.participant_code)
    end

    it "makes the phone number callable — for a lead it is the whole record" do
      get patients_path

      expect(response.body).to include(%(href="tel:+573001112222"))
    end

    it "offers a dedicated toggle for them, with a count" do
      get patients_path

      expect(response.body).to include(I18n.t("patients.filters.only_leads"))
      expect(response.body).to include("identity=lead")
    end

    it "narrows to leads alone when the toggle is on" do
      get patients_path, params: { identity: "lead" }

      expect(row?(lead)).to be(true)
      expect(row?(candidate_a)).to be(false)
      expect(row?(interested_a)).to be(false)
    end

    # "Lead" describes somebody nobody has spoken to yet, which an enrolled
    # participant no longer is; the count there would answer a question nobody
    # asked.
    it "does not offer the toggle on the participants page" do
      get potentials_patients_path

      expect(response.body).not_to include(I18n.t("patients.filters.only_leads"))
    end

    # index.json.jbuilder renders @patients; the rewrite that introduced
    # @patients_by_study left it rendering a nil collection, which Jbuilder turns
    # into [] rather than an error — a consumer told there are no patients rather
    # than told the endpoint is broken.
    it "still answers the JSON index with the patients, not an empty array" do
      get patients_path(format: :json)

      expect(response).to be_successful
      expect(response.parsed_body.size).to eq(Patient.recruiting.count)
    end

    it "keeps the other filters when the toggle is on" do
      get patients_path, params: { identity: "lead", state: "interested" }

      expect(row?(lead)).to be(false)
    end
  end

  describe "GET /patients/participants — the recruitment result" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists the enrolled patients and only those" do
      get potentials_patients_path

      expect(response).to be_successful
      expect(row?(potential_a)).to be(true)
      expect(row?(candidate_a)).to be(false)
      expect(row?(interested_a)).to be(false)
    end

    it "takes the same filters" do
      get potentials_patients_path, params: { study_id: study_b.id }

      expect(row?(potential_a)).to be(false)
    end
  end

  # THE CRITICAL RULE, end to end. The policy spec pins the scope itself; these
  # prove the pages actually go through it — including the filtered and the
  # enrolled views, which are the easy ones to forget.
  describe "who may appear on the page" do
    context "as a trial centre rep" do
      before do
        rep = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
        sign_in(rep, scope: :user)
      end

      it "shows their own centre's patients" do
        get patients_path

        expect(row?(interested_a)).to be(true)
      end

      it "never shows another centre's patient" do
        get patients_path

        expect(row?(interested_b)).to be(false)
      end

      it "still refuses another centre's patient when that centre's study is asked for by id" do
        get patients_path, params: { study_id: study_b.id }

        expect(response).to be_successful
        expect(row?(interested_b)).to be(false)
      end

      it "never shows another centre's patient on the participants page either" do
        FactoryBot.create(:patient, study: study_b, state: "potential").tap do |other|
          get potentials_patients_path

          expect(row?(potential_a)).to be(true)
          expect(row?(other)).to be(false)
        end
      end
    end

    # A sponsor rep sees no patients under the seeded matrix. These examples tick
    # can_show the way an admin would, because that is the situation in which the
    # isolation has to hold — and the situation the old scope failed open in.
    context "as a sponsor rep, once an admin grants can_show on Patient" do
      before do
        grant_patient_show!("sponsor_rep")
        rep = FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: study_a.sponsor))
        sign_in(rep, scope: :user)
      end

      it "shows their own sponsor's patients" do
        get patients_path

        expect(response).to be_successful
        expect(row?(interested_a)).to be(true)
      end

      it "NEVER shows a patient of another sponsor's study" do
        get patients_path

        expect(row?(interested_b)).to be(false)
      end

      it "does not leak another sponsor's patient through the sponsor filter" do
        get patients_path, params: { sponsor_id: study_b.sponsor_id }

        expect(response).to be_successful
        expect(row?(interested_b)).to be(false)
      end

      it "does not offer another sponsor's study as a filter option" do
        get patients_path

        expect(response.body).not_to include(study_b.display_title)
      end

      it "keeps the isolation on the participants page" do
        other = FactoryBot.create(:patient, study: study_b, state: "potential")

        get potentials_patients_path

        expect(row?(potential_a)).to be(true)
        expect(row?(other)).to be(false)
      end
    end

    # Bounced, but not to the sign-in page: ResourceAuthorization's
    # `authorize_resource` is registered on ApplicationController, so it runs
    # ahead of SecureApplicationController's `authenticate_user!` and the Pundit
    # refusal lands first. Pre-existing behaviour — what matters here is that no
    # patient row reaches an anonymous visitor by either route.
    it "shows an anonymous visitor nothing, by either route" do
      get patients_path
      expect(response).to have_http_status(:redirect)
      expect(row?(interested_a)).to be(false)

      get potentials_patients_path
      expect(response).to have_http_status(:redirect)
      expect(row?(potential_a)).to be(false)
    end
  end
  # The queue is worked top-down, so the order has to mean something: within a
  # state, the record closest to clearing the next gate comes first. That is
  # the SPECIFIC count for a candidate, because the specific tier is the one
  # standing between them and `potential`.
  describe "GET /patients — ordering within a state" do
    let(:profile) { FactoryBot.create(:criteria_profile, study: study_a) }

    let(:rules) do
      3.times.map do |i|
        profile.criteria_variables.create!(
          name: "S#{i}", variable_type: "inclusion", value_type: "quantitative",
          comparison_type: "more_than", reference_value_1: 10, criteria_category: "specific"
        )
      end
    end

    def meet(patient, count)
      rules.each_with_index do |cv, i|
        patient.variable_values.create!(
          criteria_variable: cv, name: cv.name, value: (i < count ? "50" : "1"),
          value_type: "quantitative", comparison_type: "more_than",
          variable_type: "inclusion", criteria_category: "specific", reference_value_1: 10
        )
      end
    end

    it "puts the candidate who meets the most specific criteria first" do
      thin = FactoryBot.create(:patient, study: study_a, state: "candidate")
      full = FactoryBot.create(:patient, study: study_a, state: "candidate")
      meet(thin, 1)
      meet(full, 3)

      sign_in(FactoryBot.create(:user, :admin), scope: :user)
      get patients_path

      thin_at = response.body.index(%(id="#{ActionView::RecordIdentifier.dom_id(thin)}"))
      full_at = response.body.index(%(id="#{ActionView::RecordIdentifier.dom_id(full)}"))

      expect(full_at).to be < thin_at
    end

    it "shows each row how far through the specific tier it is" do
      patient = FactoryBot.create(:patient, study: study_a, state: "candidate")
      meet(patient, 2)

      sign_in(FactoryBot.create(:user, :admin), scope: :user)
      get patients_path

      expect(response.body).to include(
        I18n.t("criteria_assessments.score.specific_count", met: 2, total: 3)
      )
    end
  end
end
