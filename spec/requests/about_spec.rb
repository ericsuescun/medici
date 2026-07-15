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

      it "renders the full manual" do
        get about_path

        expect(response).to be_successful
        # Every role's section, not just the signed-in user's own.
        OperationManual::ROLES.each do |documented_role|
          expect(response.body).to include(documented_role.display_name)
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
