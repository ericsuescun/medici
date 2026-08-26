require "rails_helper"

# OperationManual hardcodes the permission matrix so the About page reads as a
# manual rather than a database dump. These examples are the price of that
# choice: they fail the moment the manual and the real default matrix disagree,
# so the page can't quietly start lying about what a role may do.
RSpec.describe OperationManual do
  describe "roles" do
    it "documents exactly the roles that are seeded" do
      expect(described_class::ROLES.map(&:name)).to match_array(RolesAndPermissionsSeeder::ROLES.keys)
    end

    it "uses the same display names as the seeder" do
      described_class::ROLES.each do |role|
        expect(role.display_name).to eq(RolesAndPermissionsSeeder::ROLES.fetch(role.name))
      end
    end

    # The manual page renders a Mermaid flow per role. A role added without one
    # would raise a KeyError on the page rather than quietly render nothing, but
    # failing here says why.
    it "draws a flow for every documented role, and for no undocumented one" do
      expect(described_class::ROLE_FLOWS.keys).to match_array(described_class::ROLES.map(&:name))
    end

    it "writes every flow as a Mermaid flowchart with more than one step" do
      described_class::ROLE_FLOWS.each do |name, source|
        expect(source).to start_with("flowchart TD"), "#{name}'s flow is not a Mermaid flowchart"
        expect(source.scan("-->").size).to be >= 3, "#{name}'s flow has almost no steps"
      end
    end

    it "gives every role a summary and at least one responsibility" do
      described_class::ROLES.each do |role|
        expect(role.summary).to be_present, "#{role.name} has no summary"
        expect(role.responsibilities).to be_present, "#{role.name} has no responsibilities"
      end
    end
  end

  describe "permission matrix" do
    it "matches the seeded defaults for every non-admin role" do
      RolesAndPermissionsSeeder::MATRIX.each do |role_name, expected|
        documented = described_class::ROLES.find { |role| role.name == role_name }

        expect(documented).to be_present, "OperationManual does not document the '#{role_name}' role"
        expect(documented.permissions).to eq(expected),
          "the manual's '#{role_name}' permissions have drifted from RolesAndPermissionsSeeder::MATRIX"
      end
    end

    it "documents admin as full access across the whole catalog" do
      admin = described_class::ROLES.find { |role| role.name == "admin" }

      expect(admin.full_access?).to be(true)
      expect(admin.permissions.keys).to match_array(PermissionCatalog::RESOURCES)
    end

    it "only references resources that exist in the catalog" do
      described_class::ROLES.each do |role|
        expect(PermissionCatalog::RESOURCES).to include(*role.permissions.keys)
      end
    end

    it "labels every catalog resource in Spanish" do
      expect(described_class::RESOURCE_LABELS.keys).to match_array(PermissionCatalog::RESOURCES)
    end
  end

  # The lifecycle section is prose, but it describes a real state machine, and it
  # is the one part of the manual that is translated. These examples stop the
  # prose from outliving the machine, and stop a half-finished translation from
  # looking finished: I18n falls back to :es, so a missing French summary renders
  # Spanish on a French page rather than blowing up. The YAML is therefore read
  # from disk instead of through I18n, which would happily answer with the
  # fallback.
  describe "patient lifecycle" do
    def about_locale(locale)
      YAML.load_file(Rails.root.join("config/locales/content_about.#{locale}.yml"))
          .fetch(locale.to_s).fetch("operation_manual").fetch("lifecycle")
    end

    it "documents exactly the states the machine has, in lifecycle order" do
      expect(described_class::PATIENT_STATES).to eq(Patient.aasm.states.map { |s| s.name.to_s })
    end

    it "documents exactly the events the machine has" do
      expect(described_class::PATIENT_TRANSITIONS.map(&:event)).to match_array(Patient.aasm.events.map { |e| e.name.to_s })
    end

    it "moves each transition between the states the machine actually connects" do
      described_class::PATIENT_TRANSITIONS.each do |transition|
        event = Patient.aasm.events.find { |e| e.name.to_s == transition.event }
        pairs = event.transitions.map { |t| [ t.from.to_s, t.to.to_s ] }

        expect(pairs).to include([ transition.from, transition.to ]),
          "the manual says #{transition.event} goes #{transition.from} → #{transition.to}, the machine says #{pairs.inspect}"
      end
    end

    it "marks as forward exactly the steps the criteria gate" do
      forward = described_class::PATIENT_TRANSITIONS.select { |t| t.direction == :forward }.map(&:event)

      expect(forward).to match_array(Patient::FORWARD_EVENT_CHECKS.keys)
    end

    it "marks as backward exactly the steps that walk a patient back" do
      backward = described_class::PATIENT_TRANSITIONS.select { |t| t.direction == :backward }.map(&:event)

      expect(backward).to match_array(Patient::BACKWARD_EVENTS.values)
    end

    I18n.available_locales.each do |locale|
      context "in #{locale}" do
        let(:copy) { about_locale(locale) }

        it "describes every state and says how a patient gets there" do
          described_class::PATIENT_STATES.each do |state|
            entry = copy.fetch("states").fetch(state)

            expect(entry["summary"]).to be_present, "#{state} has no summary in #{locale}"
            expect(entry["arrival"]).to be_present, "#{state} does not say how a patient gets there in #{locale}"
          end
        end

        it "says who may fire every transition and what it requires" do
          described_class::PATIENT_TRANSITIONS.each do |transition|
            entry = copy.fetch("transitions").fetch(transition.event)

            expect(entry["actor"]).to be_present, "#{transition.event} does not say who may do it in #{locale}"
            expect(entry["requirement"]).to be_present, "#{transition.event} does not say what it requires in #{locale}"
          end
        end

        it "carries every standing note and every heading the page renders" do
          expect(copy["notes"]).to be_an(Array)
          expect(copy["notes"].size).to eq(described_class::PATIENT_LIFECYCLE_NOTE_COUNT)
          expect(copy["notes"]).to all(be_present)

          %w[title intro intro_note_html arrival_heading transitions_title notes_title moves_to].each do |key|
            expect(copy[key]).to be_present, "lifecycle.#{key} is missing in #{locale}"
          end
          %w[action change who requires].each do |key|
            expect(copy.fetch("table")[key]).to be_present, "lifecycle.table.#{key} is missing in #{locale}"
          end
          %w[forward backward].each do |key|
            expect(copy.fetch("direction")[key]).to be_present, "lifecycle.direction.#{key} is missing in #{locale}"
          end
        end
      end
    end
  end

  describe "documents" do
    it "gives every document a title, an issuer and a note" do
      (described_class::DOCUMENTS + described_class::INTERNAL_DOCUMENTS).each do |document|
        expect(document.title).to be_present
        expect(document.issuer).to be_present
        expect(document.note).to be_present
      end
    end

    # A document without a verified public URL is rendered title-only rather
    # than linked to a guessed source.
    it "only links regulatory documents over https" do
      described_class::DOCUMENTS.filter_map(&:url).each do |url|
        expect(url).to start_with("https://")
      end
    end

    it "does not link internal analysis, which the app never serves" do
      expect(described_class::INTERNAL_DOCUMENTS.map(&:url)).to all(be_nil)
    end
  end

  describe "features" do
    it "assigns every feature a known status and a detail" do
      described_class::FEATURES.each do |feature|
        expect(%i[done partial pending blocked]).to include(feature.status), "#{feature.name} has an unknown status"
        expect(feature.detail).to be_present, "#{feature.name} has no detail"
      end
    end

    it "splits the inventory into shipped and outstanding without losing any" do
      expect(described_class.shipped + described_class.outstanding).to match_array(described_class::FEATURES)
      expect(described_class.shipped).to all(have_attributes(status: :done))
      expect(described_class.outstanding).not_to include(have_attributes(status: :done))
    end
  end
end
