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
