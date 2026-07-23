require 'rails_helper'

RSpec.describe "Local parameters (admin manager)", type: :request do
  let!(:parameter) { FactoryBot.create(:local_parameter, :health_authority) }

  context "as a non-admin" do
    before { sign_in(FactoryBot.create(:user, :trial_center_branch_rep), scope: :user) }

    it "is blocked from the index" do
      get local_parameters_path
      expect(response).to have_http_status(:redirect)
    end

    it "cannot change a parameter" do
      patch local_parameter_path(parameter), params: { local_parameter: { value: "OTRO" } }

      expect(response).to have_http_status(:redirect)
      expect(parameter.reload.value).to eq("INVIMA")
    end
  end

  context "as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists the configured parameters" do
      get local_parameters_path

      expect(response).to be_successful
      expect(response.body).to include("INVIMA")
      expect(response.body).to include("Colombia")
    end

    it "opens the new and edit forms" do
      get new_local_parameter_path
      expect(response).to be_successful

      get edit_local_parameter_path(parameter)
      expect(response).to be_successful
    end

    it "creates a parameter for another country" do
      argentina = FactoryBot.create(:country, name: "Argentina", code: "AR")

      expect do
        post local_parameters_path, params: {
          local_parameter: {
            country_id: argentina.id,
            name: LocalParameter::LOCAL_HEALTH_AUTHORITY,
            value: "ANMAT",
            display_name: "ANMAT",
            description: "Administración Nacional de Medicamentos, Alimentos y Tecnología Médica"
          }
        }
      end.to change(LocalParameter, :count).by(1)

      expect(response).to redirect_to(local_parameters_path)
      expect(LocalParameter.health_authority_label(country: argentina)).to eq("ANMAT")
    end

    it "re-renders the form when the parameter is invalid" do
      post local_parameters_path, params: { local_parameter: { country_id: parameter.country_id, name: "", value: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates and deletes a parameter" do
      patch local_parameter_path(parameter), params: { local_parameter: { value: "INVIMA", display_name: "INVIMA (CO)" } }
      expect(parameter.reload.label).to eq("INVIMA (CO)")

      expect { delete local_parameter_path(parameter) }.to change(LocalParameter, :count).by(-1)
    end
  end
end
