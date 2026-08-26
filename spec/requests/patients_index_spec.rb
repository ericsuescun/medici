require "rails_helper"

# The recruitment index and the participants page, end to end: what each one is
# for, and — the part that matters most — who is allowed to appear on them.
#
# Rows are matched by dom_id rather than by name: a patient who arrived through
# the public form has no name at all, and the name column is encrypted.
RSpec.describe "Patients index and participants", type: :request do
  let(:city) { FactoryBot.create(:city) }
  let(:branch_a) { FactoryBot.create(:trial_center_branch).tap { |b| b.cities << city } }
  let(:branch_b) { FactoryBot.create(:trial_center_branch) }

  let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
  let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }

  let!(:interested_a) { FactoryBot.create(:patient, study: study_a, state: "interested") }
  let!(:candidate_a) { FactoryBot.create(:patient, study: study_a, state: "candidate") }
  let!(:participant_a) { FactoryBot.create(:patient, study: study_a, state: "participant") }
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

      expect(row?(participant_a)).to be(false)
    end

    it "cannot be talked into showing an enrolled patient through the state filter" do
      get patients_path, params: { state: "participant" }

      expect(response).to be_successful
      expect(row?(participant_a)).to be(false)
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
      get participants_patients_path

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
      get participants_patients_path

      expect(response).to be_successful
      expect(row?(participant_a)).to be(true)
      expect(row?(candidate_a)).to be(false)
      expect(row?(interested_a)).to be(false)
    end

    it "takes the same filters" do
      get participants_patients_path, params: { study_id: study_b.id }

      expect(row?(participant_a)).to be(false)
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
        FactoryBot.create(:patient, study: study_b, state: "participant").tap do |other|
          get participants_patients_path

          expect(row?(participant_a)).to be(true)
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
        other = FactoryBot.create(:patient, study: study_b, state: "participant")

        get participants_patients_path

        expect(row?(participant_a)).to be(true)
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

      get participants_patients_path
      expect(response).to have_http_status(:redirect)
      expect(row?(participant_a)).to be(false)
    end
  end
end
