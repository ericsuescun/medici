require 'rails_helper'

# The study type is chosen before the form opens (the index offers one button
# per type) and decides which single approval the form asks about.
RSpec.describe "Study type and approvals", type: :request do
  let(:admin) { FactoryBot.create(:user, :admin) }
  let(:sponsor) { FactoryBot.create(:sponsor) }
  let(:branch) { FactoryBot.create(:trial_center_branch) }

  before { sign_in(admin, scope: :user) }

  describe "GET /studies/new" do
    it "asks an observational study about the ethics committee" do
      get new_study_path(study_type: "observational")

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("studies.form.committee_approved"))
      expect(response.body).not_to include(I18n.t("studies.form.local_health_authority_approved"))
    end

    it "names the local health authority from the local parameters" do
      FactoryBot.create(:local_parameter, :health_authority)

      get new_study_path(study_type: "interventional")

      # The question names the regulator; the cryptic parameter key only ever
      # appears as the checkbox's field name, never as the label a user reads.
      expect(response.body).to include(I18n.t("studies.form.authority_approved", authority: "INVIMA"))
      expect(response.body).not_to include(I18n.t("studies.form.local_health_authority_approved"))
    end

    it "falls back to a generic label when no authority is configured" do
      get new_study_path(study_type: "interventional")

      expect(response.body).to include(I18n.t("studies.form.local_health_authority_approved"))
    end

    it "falls back to interventional for a missing or unknown type" do
      get new_study_path
      expect(response.body).to include(I18n.t("studies.form.local_health_authority_approved"))

      get new_study_path(study_type: "nonsense")
      expect(response.body).to include(I18n.t("studies.form.local_health_authority_approved"))
    end
  end

  describe "the studies index" do
    it "offers one creation entry point per study type instead of a generic one" do
      get studies_path

      expect(response.body).to include(new_study_path(study_type: "observational"))
      expect(response.body).to include(new_study_path(study_type: "interventional"))
    end
  end

  describe "GET /studies/:id/edit" do
    it "lets the type be corrected and asks the approval its current type implies" do
      study = FactoryBot.create(:study, study_type: "observational")

      get edit_study_path(study)

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("studies.form.study_type_help"))
      expect(response.body).to include(I18n.t("studies.form.committee_approved"))
    end

    it "switches the approval question when the type is changed" do
      study = FactoryBot.create(:study, study_type: "observational", committee_approved: true)
      FactoryBot.create(:local_parameter, :health_authority)

      patch study_path(study), params: { study: { study_type: "interventional" } }
      expect(study.reload).to be_interventional

      get edit_study_path(study)
      expect(response.body).to include(I18n.t("studies.form.authority_approved", authority: "INVIMA"))
      expect(response.body).not_to include(I18n.t("studies.form.committee_approved"))
    end
  end

  describe "POST /studies" do
    def study_attributes(overrides = {})
      {
        public_title: "Estudio X", scientific_title: "Estudio científico X", short_title: "EX",
        sponsor_id: sponsor.id, trial_center_branch_id: branch.id
      }.merge(overrides)
    end

    it "creates an observational study with its committee approval" do
      post studies_path, params: {
        study: study_attributes(study_type: "observational", committee_approved: "1")
      }

      study = Study.order(:created_at).last
      expect(study).to be_observational
      expect(study.committee_approved).to be(true)
      expect(study.local_health_authority_approved).to be(false)
      expect(study.approval_attribute).to eq(:committee_approved)
      expect(study).to be_approved
    end

    it "creates an interventional study with its health-authority approval" do
      post studies_path, params: {
        study: study_attributes(study_type: "interventional", local_health_authority_approved: "1")
      }

      study = Study.order(:created_at).last
      expect(study).to be_interventional
      expect(study.local_health_authority_approved).to be(true)
      expect(study.committee_approved).to be(false)
      expect(study.approval_attribute).to eq(:local_health_authority_approved)
    end

    it "refuses a study with no type" do
      expect do
        post studies_path, params: { study: study_attributes(study_type: "") }
      end.not_to change(Study, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
