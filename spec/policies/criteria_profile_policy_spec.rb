require "rails_helper"

# The eligibility criteria moved from the trial centre to the sponsor on
# 2026-08-25 — they come from the protocol, and the protocol is the sponsor's.
#
# The permission grant that expresses that is class-level, so these examples are
# the other half of it. Without a Scope, `can_edit` on CriteriaProfile would let
# ANY sponsor rep rewrite ANY sponsor's criteria — and since those criteria gate
# promotion (Patient's AASM guards read them), that is a forgeable eligibility
# gate, not merely a disclosure.
RSpec.describe CriteriaProfilePolicy do
  let(:sponsor_a) { FactoryBot.create(:sponsor) }
  let(:sponsor_b) { FactoryBot.create(:sponsor) }

  let(:branch_a) { FactoryBot.create(:trial_center_branch) }
  let(:branch_b) { FactoryBot.create(:trial_center_branch) }

  let(:study_a) { FactoryBot.create(:study, sponsor: sponsor_a).tap { |s| s.trial_center_branches << branch_a } }
  let(:study_b) { FactoryBot.create(:study, sponsor: sponsor_b).tap { |s| s.trial_center_branches << branch_b } }

  # Owned by an admin on purpose: that is how the seeds create them, and it is
  # exactly the case creator-ownership got wrong — a sponsor rep would have
  # reached none of their own studies' criteria.
  let(:admin) { FactoryBot.create(:user, :admin) }
  let!(:profile_a) { FactoryBot.create(:criteria_profile, study: study_a, user: admin) }
  let!(:profile_b) { FactoryBot.create(:criteria_profile, study: study_b, user: admin) }

  def rep_for(sponsor)
    FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: sponsor))
  end

  def rep_at(branch)
    FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch))
  end

  def resolved_for(user)
    described_class::Scope.new(user, CriteriaProfile).resolve
  end

  describe "Scope" do
    it "gives a sponsor rep their own sponsor's study profiles, whoever typed them in" do
      expect(resolved_for(rep_for(sponsor_a))).to contain_exactly(profile_a)
    end

    it "NEVER gives one sponsor another sponsor's criteria" do
      resolved = resolved_for(rep_for(sponsor_b))

      expect(resolved).to contain_exactly(profile_b)
      expect(resolved).not_to include(profile_a)
    end

    it "fails closed for a sponsor rep with no sponsor" do
      rep = rep_for(sponsor_a)
      rep.userable.update_column(:sponsor_id, nil)

      expect(resolved_for(rep.reload)).to be_empty
    end

    it "lets a centre rep read the criteria of the studies that run at their branch" do
      expect(resolved_for(rep_at(branch_a))).to contain_exactly(profile_a)
    end

    it "does not show a centre rep another centre's criteria" do
      expect(resolved_for(rep_at(branch_a))).not_to include(profile_b)
    end

    it "shows an admin everything" do
      expect(resolved_for(admin)).to contain_exactly(profile_a, profile_b)
    end

    it "shows nothing to an anonymous visitor" do
      expect(resolved_for(nil)).to be_empty
    end

    it "shows nothing to a role with no criteria access at all" do
      expect(resolved_for(FactoryBot.create(:user, :platform_staff))).to be_empty
    end

    # `study_id: nil` profiles are reusable templates: they belong to nobody's
    # study, so creator ownership is the only rule left that means anything.
    context "with an unattached template" do
      let!(:template) { FactoryBot.create(:criteria_profile, study: nil, user: rep_for(sponsor_a)) }

      it "shows a template to the person who made it" do
        expect(resolved_for(template.user)).to include(template)
      end

      it "does not show it to another rep of the same sponsor" do
        expect(resolved_for(rep_for(sponsor_a))).not_to include(template)
      end
    end
  end

  describe "the permission that made the Scope necessary" do
    it "gives the sponsor rep view and edit on criteria, and the centre view only" do
      expect(RolesAndPermissionsSeeder::MATRIX.dig("sponsor_rep", "CriteriaProfile")).to eq([ true, true, false ])
      expect(RolesAndPermissionsSeeder::MATRIX.dig("trial_center_branch_rep", "CriteriaProfile")).to eq([ true, false, false ])
    end

    # Recording a patient's VALUES is a Patient permission, not a criteria one —
    # CriteriaAssessmentsController overrides authorization_model to nil and is
    # gated by the parent patient's visibility. The centre losing edit on the
    # profile must not have taken screening with it.
    it "leaves the centre able to record patient values" do
      expect(RolesAndPermissionsSeeder::MATRIX.dig("trial_center_branch_rep", "Patient")).to eq([ true, true, false ])
    end
  end
end
