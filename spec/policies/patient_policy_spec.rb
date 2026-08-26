require 'rails_helper'

RSpec.describe PatientPolicy do
  subject { described_class }

  let(:admin) { FactoryBot.create(:user, :admin) }
  let(:trial_rep) { FactoryBot.create(:user, :trial_center_branch_rep) }
  let(:patient_user) { FactoryBot.create(:user, :patient) }
  let(:sponsor_rep) { FactoryBot.create(:user, :sponsor_rep) }
  let(:record) { FactoryBot.create(:patient) }

  permissions :show_state?, :update_state? do
    it "permits admins and trial center reps" do
      expect(subject).to permit(admin, record)
      expect(subject).to permit(trial_rep, record)
    end

    it "denies patients, sponsor reps, and anonymous users" do
      expect(subject).not_to permit(patient_user, record)
      expect(subject).not_to permit(sponsor_rep, record)
      expect(subject).not_to permit(nil, record)
    end
  end

  permissions :assess? do
    it "permits an authorized role when the AASM guard allows it" do
      expect(subject).to permit(admin, record) # interested => may_assess? true
    end

    it "denies when the AASM guard forbids the transition" do
      record.assess! # now candidate => may_assess? false
      expect(subject).not_to permit(admin, record)
    end

    it "denies unauthorized roles even when the guard allows it" do
      expect(subject).not_to permit(patient_user, record)
    end
  end

  permissions :accept? do
    it "denies an admin while the patient is still interested" do
      expect(subject).not_to permit(admin, record) # may_accept? false from interested
    end

    it "permits an admin once the patient is a candidate" do
      record.assess!
      expect(subject).to permit(admin, record)
    end
  end

  # Who may see WHICH patients. Before this scope existed, the inherited one
  # returned scope.all to any role with can_show on Patient — so every trial
  # centre rep could list every patient of every study, including centres they
  # have nothing to do with.
  describe described_class::Scope do
    let(:branch_a) { FactoryBot.create(:trial_center_branch) }
    let(:branch_b) { FactoryBot.create(:trial_center_branch) }

    let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
    let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }

    let!(:patient_a) { FactoryBot.create(:patient, study: study_a) }
    let!(:patient_b) { FactoryBot.create(:patient, study: study_b) }

    def rep_at(branch)
      FactoryBot.create(
        :user,
        userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch)
      )
    end

    def resolved_for(user)
      described_class.new(user, Patient).resolve
    end

    it "shows a trial centre rep only the patients of their own centre" do
      expect(resolved_for(rep_at(branch_a))).to contain_exactly(patient_a)
    end

    it "does not leak another centre's patient to a rep" do
      expect(resolved_for(rep_at(branch_a))).not_to include(patient_b)
    end

    it "shows an admin every patient, across centres" do
      expect(resolved_for(admin)).to contain_exactly(patient_a, patient_b)
    end

    # The model requires a branch, but the column is nullable — an older row can
    # still have none. The scope must fail closed rather than fall open to
    # everything.
    it "shows nothing to a rep with no centre assigned — fails closed" do
      rep = rep_at(branch_a)
      rep.userable.update_column(:trial_center_branch_id, nil)

      expect(resolved_for(rep.reload)).to be_empty
    end

    it "shows nothing to a role with no patient access at all" do
      expect(resolved_for(sponsor_rep)).to be_empty
    end

    it "shows nothing to an anonymous visitor" do
      expect(resolved_for(nil)).to be_empty
    end

    # THE SPONSOR RULE. A sponsor must never see another sponsor's patients.
    #
    # `sponsor_rep` has no Patient row in the seeded matrix, so today it sees
    # nothing at all — which is exactly what made the old scope look safe. It
    # narrowed only for trial centre reps and handed every other role `super`,
    # i.e. `scope.all` for anyone holding can_show. These examples tick can_show
    # the way an admin would in the role manager, and prove the scope still
    # isolates by sponsor afterwards. Delete them and a permission grant silently
    # becomes a cross-sponsor disclosure again.
    def grant_patient_show!(role_name)
      role = Role.find_by!(name: role_name)
      permission = role.role_permissions.find_or_initialize_by(resource: "Patient")
      permission.update!(can_show: true)
    end

    context "for a sponsor rep, once an admin grants can_show on Patient" do
      before { grant_patient_show!("sponsor_rep") }

      def rep_for(sponsor)
        FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: sponsor))
      end

      it "shows a sponsor rep only their own sponsor's patients" do
        expect(resolved_for(rep_for(study_a.sponsor))).to contain_exactly(patient_a)
      end

      it "never leaks another sponsor's patient" do
        resolved = resolved_for(rep_for(study_b.sponsor))

        expect(resolved).to contain_exactly(patient_b)
        expect(resolved).not_to include(patient_a)
      end

      # The column is nullable, so a rep can exist with no sponsor attached.
      it "shows nothing to a rep with no sponsor — fails closed" do
        rep = rep_for(study_a.sponsor)
        rep.userable.update_column(:sponsor_id, nil)

        expect(resolved_for(rep.reload)).to be_empty
      end

      it "still shows a trial centre rep their centre's patients, sponsor or not" do
        expect(resolved_for(rep_at(branch_a))).to contain_exactly(patient_a)
      end
    end

    # Deny by default: a role has to be NAMED in the scope to see anything. A
    # permission grant may widen WHAT a role sees, never WHOSE records.
    context "for platform staff, once an admin grants can_show on Patient" do
      before { grant_patient_show!("platform_staff") }

      it "still shows nothing — platform staff have no relationship to a patient" do
        staff = FactoryBot.create(:user, :platform_staff)

        expect(resolved_for(staff)).to be_empty
      end
    end

    context "when a study runs at more than one centre" do
      before { study_a.trial_center_branches << branch_b }

      it "shows that study's patients to the reps of both centres" do
        expect(resolved_for(rep_at(branch_b))).to contain_exactly(patient_a, patient_b)
      end

      it "does not return the same patient twice" do
        expect(resolved_for(rep_at(branch_a)).to_a.size).to eq(1)
      end
    end
  end

  # The one rule a scope cannot express: a rep must not enrol a patient INTO a
  # study that does not run at their centre.
  describe "#enrol_into?" do
    let(:branch_a) { FactoryBot.create(:trial_center_branch) }
    let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
    let(:study_elsewhere) { FactoryBot.create(:study) }
    let(:rep_a) do
      FactoryBot.create(
        :user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a)
      )
    end

    it "lets an admin enrol into any study" do
      expect(described_class.new(admin, Patient).enrol_into?(study_elsewhere)).to be(true)
    end

    it "lets a rep enrol into a study at their own centre" do
      expect(described_class.new(rep_a, Patient).enrol_into?(study_a)).to be(true)
    end

    # The form only offers the rep's own studies, but a hand-crafted POST must
    # not get past this.
    it "stops a rep enrolling into another centre's study" do
      expect(described_class.new(rep_a, Patient).enrol_into?(study_elsewhere)).to be(false)
    end

    it "refuses a role that cannot touch patients at all" do
      expect(described_class.new(sponsor_rep, Patient).enrol_into?(study_a)).to be(false)
    end

    it "refuses when no study is given" do
      expect(described_class.new(rep_a, Patient).enrol_into?(nil)).to be(false)
    end
  end
end
