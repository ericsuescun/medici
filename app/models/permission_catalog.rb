# Single source of truth for the resources whose access is governed by
# Role -> RolePermission. Used by the seeder, RolePermission validation, and the
# admin role-manager UI so they never drift apart.
module PermissionCatalog
  RESOURCES = %w[
    Article
    Campaign
    CampaignDocument
    City
    Contact
    CriteriaProfile
    CriteriaVariable
    Medication
    Patient
    PlatformStaff
    Result
    SponsorRep
    Sponsor
    Study
    TrialCenterBranch
    TrialCenterBranchRep
    TrialCenterFacility
    TrialCity
    Admin
    User
  ].freeze

  ACTIONS = %i[can_show can_edit can_delete].freeze
end
