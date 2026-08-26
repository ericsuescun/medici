require "rails_helper"

# The operation manual spells out the permission matrix and the open compliance
# gaps: internal operational detail. Every signed-in role reads all of it;
# anonymous visitors get none of it.
RSpec.describe "About", type: :request do
  it "sends an anonymous visitor to sign in" do
    get about_path
    expect(response).to redirect_to(new_user_session_path)
  end

  %i[admin platform_staff sponsor_rep trial_center_branch_rep patient].each do |role|
    context "as a #{role}" do
      before { sign_in create(:user, role) }

      # The per-role manual moved to /manual on 2026-08-25. This page now points
      # at it rather than containing it — see spec/requests/manual_spec.rb.
      it "points at the per-role manual instead of inlining it" do
        get about_path

        expect(response).to be_successful
        expect(response.body).to include(manual_path)
        expect(response.body).to include("Abrir el manual")
      end

      it "renders the patient lifecycle: every state and every way out of it" do
        get about_path

        OperationManual::PATIENT_STATES.each do |state|
          expect(response.body).to include(I18n.t("patients.states.#{state}"))
          expect(response.body).to include(
            ERB::Util.html_escape(I18n.t("operation_manual.lifecycle.states.#{state}.summary"))
          )
        end

        OperationManual::PATIENT_TRANSITIONS.each do |transition|
          expect(response.body).to include(
            ERB::Util.html_escape(I18n.t("operation_manual.lifecycle.transitions.#{transition.event}.requirement"))
          )
        end
      end

      it "renders the regulatory sources and the feature inventory" do
        get about_path

        expect(response.body).to include("Ley 1581 de 2012")
        expect(response.body).to include("https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981")
        expect(response.body).to include("Lo que tenemos", "Lo que falta")
      end
    end
  end

  context "as a signed-in user" do
    before { sign_in create(:user, :admin) }

    it "shows a document with no verified URL as text rather than a link" do
      unlinked = OperationManual::DOCUMENTS.find { |document| document.url.nil? }

      get about_path

      expect(response.body).to include(unlinked.title)
      expect(response.body).to include("Sin enlace verificado")
    end
  end
end
