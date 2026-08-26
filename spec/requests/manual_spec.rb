require "rails_helper"

# The per-role operation manual. Split off /about on 2026-08-25 because it is
# read on its own — to answer "what does this role actually do" — rather than
# alongside the regulatory sources it used to sit above.
#
# Like /about it is internal operational detail (it spells out the permission
# matrix), so every signed-in role reads all of it and anonymous visitors get
# none of it.
RSpec.describe "Manual", type: :request do
  it "shows an anonymous visitor nothing" do
    get manual_path

    expect(response).to have_http_status(:redirect)
    expect(response.body).not_to include("Manual de operación")
  end

  %i[admin platform_staff sponsor_rep trial_center_branch_rep patient].each do |role|
    context "as a #{role}" do
      before { sign_in create(:user, role) }

      it "documents every role, not just the signed-in user's own" do
        get manual_path

        expect(response).to be_successful
        OperationManual::ROLES.each do |documented_role|
          expect(response.body).to include(documented_role.display_name)
          expect(response.body).to include(ERB::Util.html_escape(documented_role.summary))
        end
      end

      it "draws a flow for each of them" do
        get manual_path

        OperationManual::ROLES.each do |documented_role|
          expect(response.body).to include(%(id="#{documented_role.name}"))
        end
        # One <pre class="mermaid"> per role, each carrying its own source.
        expect(response.body.scan('class="mermaid').size).to eq(OperationManual::ROLES.size)
        expect(response.body).to include("flowchart TD")
      end

      it "loads the Mermaid bundle on this page" do
        get manual_path

        expect(response.body).to match(%r{<script src="/assets/mermaid\.min-[^"]+\.js"})
      end

      it "still spells out the permission matrix" do
        get manual_path

        expect(response.body).to include("Permisos por defecto")
        expect(response.body).to include(OperationManual.resource_label("Patient"))
      end

      it "links back to Acerca de, which keeps the normativa and the platform status" do
        get manual_path

        expect(response.body).to include(about_path)
      end
    end
  end

  # The flows describe what the code does, not what a role is nominally for.
  # These two are the load-bearing cases: get them wrong and the manual teaches
  # a rep something the app will refuse to do.
  describe "the flows tell the truth about the app" do
    before { sign_in create(:user, :admin) }

    # Flipped 2026-08-25, deliberately rather than deleted: the eligibility
    # criteria moved from the centre to the sponsor, because they come from the
    # protocol. The manual has to move with the matrix or it teaches a rep
    # something the app will refuse to do.
    it "tells a sponsor rep they define the eligibility criteria, and the matrix agrees" do
      matrix = RolesAndPermissionsSeeder::MATRIX.fetch("sponsor_rep")

      expect(matrix["CriteriaProfile"]).to eq([ true, true, false ])
      expect(matrix["CriteriaVariable"]).to eq([ true, true, false ])
      expect(OperationManual::ROLE_FLOWS.fetch("sponsor_rep")).to include("Define el perfil de criterios")
    end

    it "tells a centre rep they read those criteria rather than write them" do
      matrix = RolesAndPermissionsSeeder::MATRIX.fetch("trial_center_branch_rep")

      expect(matrix["CriteriaProfile"]).to eq([ true, false, false ])
      expect(OperationManual::ROLE_FLOWS.fetch("trial_center_branch_rep")).to include("Consulta el perfil de criterios")
    end

    it "shows the patient reaching Candidato without anyone logging in" do
      flow = OperationManual::ROLE_FLOWS.fetch("patient")

      expect(flow).to include("no existe cuenta de paciente")
      expect(flow).to include("system:self-report-triage")
      # Narrowed with the controller on 2026-08-25: the questionnaire now says
      # whether the study is a match, and still never says WHICH criterion —
      # and it shows the exclusions upfront so nobody answers into silence.
      expect(flow).to include("ve las exclusiones")
      expect(flow).to include("nunca se le dice qué criterio")
    end
  end
end
