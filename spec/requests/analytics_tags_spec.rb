require "rails_helper"

# The measurement tags are the one thing in the app that hands data to a third
# party, so what these specs actually protect is the boundary: they must appear
# on the public marketing pages and must NOT appear anywhere that says something
# about a visitor's health.
RSpec.describe "Google/Meta measurement tags", type: :request do
  around do |example|
    # No ClimateControl in this project, so set and restore ENV by hand.
    original = ENV.to_hash.slice("GA4_MEASUREMENT_ID", "META_PIXEL_ID", "ANALYTICS_ENABLED", "GOOGLE_SITE_VERIFICATION")
    ENV["GA4_MEASUREMENT_ID"] = "G-TESTID"
    ENV["META_PIXEL_ID"] = "111122223333444"
    ENV["ANALYTICS_ENABLED"] = "true"
    example.run
  ensure
    %w[GA4_MEASUREMENT_ID META_PIXEL_ID ANALYTICS_ENABLED GOOGLE_SITE_VERIFICATION].each { |k| ENV.delete(k) }
    original.each { |k, v| ENV[k] = v }
  end

  describe "public marketing pages" do
    it "loads gtag and the analytics controller on the home page" do
      get root_path

      expect(response.body).to include("googletagmanager.com/gtag/js?id=G-TESTID")
      expect(response.body).to include('data-controller="analytics"')
      expect(response.body).to include("111122223333444")
    end

    it "defaults every Consent Mode storage type to denied" do
      get root_path

      expect(response.body).to include('gtag("consent", "default"')
      expect(response.body).to include('analytics_storage: "denied"')
      expect(response.body).to include('ad_user_data: "denied"')
      # Granting anything by default would defeat the banner entirely.
      expect(response.body).not_to include('analytics_storage: "granted"')
    end

    it "renders the consent banner, hidden until the controller reveals it" do
      get root_path

      expect(response.body).to include("cookie-consent")
      expect(response.body).to include('data-analytics-target="banner"')
    end

    it "tags the ¡Quiero participar! call to action" do
      study = FactoryBot.create(:study)

      get root_path

      expect(response.body).to include('data-action="click-&gt;analytics#track"')
      expect(response.body).to include('data-analytics-name-param="click_participate"')
      expect(response.body).to include(new_participation_request_path(study_id: study.id))
    end

    it "loads on a public study page" do
      study = FactoryBot.create(:study)

      get study_about_path(study)

      expect(response.body).to include('data-controller="analytics"')
    end
  end

  describe "pages that say something about a visitor's health" do
    it "does not load on the participation form" do
      study = FactoryBot.create(:study)

      get new_participation_request_path(study_id: study.id)

      expect(response.body).not_to include("googletagmanager")
      expect(response.body).not_to include('data-controller="analytics"')
      expect(response.body).not_to include("cookie-consent")
    end

    it "does not load on the self-report questionnaire" do
      study = FactoryBot.create(:study, patient_self_report_enabled: true)
      patient = FactoryBot.create(:patient, study: study)

      # The questionnaire identifies the patient from the session stamp step 1 wrote.
      allow_any_instance_of(SelfReportsController).to receive(:set_patient_from_session) do |controller|
        controller.instance_variable_set(:@patient, patient)
      end

      get study_self_report_path(study)

      expect(response.body).not_to include("googletagmanager")
      expect(response.body).not_to include('data-controller="analytics"')
    end
  end

  describe "signed-in traffic" do
    it "is never measured — staff traffic is not marketing traffic" do
      sign_in FactoryBot.create(:user, :admin)

      get root_path

      expect(response.body).not_to include("googletagmanager")
      expect(response.body).not_to include('data-controller="analytics"')
    end
  end

  describe "when nothing is configured" do
    it "emits no tags at all" do
      ENV.delete("GA4_MEASUREMENT_ID")
      ENV.delete("META_PIXEL_ID")

      get root_path

      expect(response.body).not_to include("googletagmanager")
      expect(response.body).not_to include('data-controller="analytics"')
      expect(response.body).not_to include("cookie-consent")
    end
  end

  describe "the conversion, reported on the next measured page" do
    it "flags a submitted participation request" do
      study = FactoryBot.create(:study)

      post participation_requests_path(study_id: study.id), params: {
        patient: {
          contact_number: "3001234567",
          adult_confirmed: "1",
          data_processing_authorization: "1"
        }
      }

      expect(response).to redirect_to(study_about_path(study))
      follow_redirect!

      expect(response.body).to include("participation_submitted")
    end

    it "reports nothing on an ordinary visit" do
      get root_path

      expect(response.body).not_to include("participation_submitted")
    end
  end
end
