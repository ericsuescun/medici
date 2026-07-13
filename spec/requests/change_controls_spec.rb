require 'rails_helper'

RSpec.describe "Change control (audit log)", type: :request do
  let(:patient) { FactoryBot.create(:patient) }

  def change_control_for(item, **params)
    change_control_path(item.class.name, item.id, **params)
  end

  context "as an admin" do
    let(:admin_user) { FactoryBot.create(:user, :admin) }
    before { sign_in(admin_user, scope: :user) }

    def make_change!(attrs)
      PaperTrail.request(whodunnit: admin_user.id.to_s) { patient.update!(attrs) }
    end

    it "renders the change log with a field-level diff attributed to the user" do
      make_change!(notes: "seen in clinic")

      get change_control_for(patient)

      expect(response).to be_successful
      expect(response.body).to include("Control de cambios")
      expect(response.body).to include("Notes") # humanized attribute name
      expect(response.body).to include("seen in clinic")
      expect(response.body).to include(admin_user.fullname.presence || admin_user.email)
    end

    it "filters by event type" do
      make_change!(notes: "first")

      # Only 'update' events exist; filtering to 'destroy' yields nothing.
      get change_control_for(patient, event: "destroy")
      expect(response.body).to include("No hay cambios que coincidan")

      get change_control_for(patient, event: "update")
      expect(response.body).to include("first")
    end

    it "exports the change log as CSV" do
      make_change!(notes: "csv row")

      get change_control_for(patient, format: :csv)

      expect(response).to be_successful
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("fecha,evento,usuario,campo,antes,despues")
      expect(response.body).to include("csv row")
    end

    it "404s for an untracked / unknown type" do
      get change_control_path("Sponsor", 1)
      expect(response).to have_http_status(:not_found)
    end
  end

  context "as a non-admin (patient)" do
    before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

    it "is blocked" do
      get change_control_for(patient)
      expect(response).to have_http_status(:redirect)
    end
  end

  context "when signed out" do
    it "redirects to sign in" do
      get change_control_for(patient)
      expect(response).to have_http_status(:redirect)
    end
  end
end
