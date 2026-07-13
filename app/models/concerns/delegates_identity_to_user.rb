# Identity (name/email) delegation for userable roles that DON'T store their own
# identity — Admin, SponsorRep, TrialCenterBranchRep read it from the User.
#
# Patient deliberately does NOT include this: it owns encrypted identity columns
# so participant data can be pseudonymized independently of the shared User row.
module DelegatesIdentityToUser
  extend ActiveSupport::Concern

  included do
    delegate :firstname, :lastname, :email, :fullname, to: :user, allow_nil: true
  end
end
