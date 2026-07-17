# Global navbar search across the records a user is allowed to see.
#
# Every group is gated twice, to match the app's access model:
#   1. Permission — the role must have `can_show` on the resource
#      (Role#permits?), the same flag the Pundit policies use. A role that
#      can't see Patients never gets a Patients group.
#   2. Scope — a trial centre rep is limited to THEIR branch's records
#      (studies, patients, the branch/facility itself, its reps and cities),
#      mirroring PatientPolicy::Scope. Admins see everything. Other roles see
#      every row of the resources they're permitted (no branch to scope by),
#      which is exactly what the inherited Pundit scope already grants them.
#
# Results come back grouped by record type so the view can classify them.
class GlobalSearch
  # One record-type section of the results.
  Group = Struct.new(:type, :records, keyword_init: true)
  # A city plus the studies (already user-scoped) that run in it.
  CityResult = Struct.new(:city, :studies, keyword_init: true)

  LIMIT = 10

  def initialize(user:, query:)
    @user = user
    @query = query.to_s.strip
  end

  def call
    return [] if @query.blank?

    [
      studies_group,
      trial_centers_group,
      reps_group,
      patients_group,
      cities_group
    ].compact.reject { |group| group.records.empty? }
  end

  private

  attr_reader :user, :query

  # ---- Groups ----

  def studies_group
    return unless can_show?(Study)

    records = study_scope
              .where("public_title ILIKE :q OR short_title ILIKE :q OR scientific_title ILIKE :q", q: ilike)
              .order(:public_title).limit(LIMIT)
    Group.new(type: :studies, records: records.to_a)
  end

  def trial_centers_group
    centers = []

    if can_show?(TrialCenterBranch)
      centers += branch_scope
                 .where("name ILIKE :q OR description ILIKE :q OR initials ILIKE :q", q: ilike)
                 .limit(LIMIT).to_a
    end

    if can_show?(TrialCenterFacility)
      centers += facility_scope
                 .where("name ILIKE :q OR description ILIKE :q OR initials ILIKE :q", q: ilike)
                 .limit(LIMIT).to_a
    end

    Group.new(type: :trial_centers, records: centers)
  end

  def reps_group
    reps = []

    if can_show?(TrialCenterBranchRep)
      reps += reps_matching(branch_rep_scope)
    end

    # Sponsor reps aren't branch-scoped (they belong to a sponsor, not a centre);
    # the permission flag alone decides who sees them.
    if can_show?(SponsorRep)
      reps += reps_matching(admin? || user.sponsor? ? SponsorRep.all : SponsorRep.none)
    end

    Group.new(type: :reps, records: reps)
  end

  def patients_group
    return unless can_show?(Patient)

    # Patient identity is deterministically encrypted, so only EXACT matches work
    # on names/email (ciphertext can't be ILIKE'd). participant_code is plaintext.
    base = PatientPolicy::Scope.new(user, Patient.all).resolve
    ids = []
    ids += base.where(firstname: query).limit(LIMIT).ids
    ids += base.where(lastname: query).limit(LIMIT).ids
    ids += base.where(email: [ query, query.downcase ].uniq).limit(LIMIT).ids
    if (parts = query.split).size == 2
      ids += base.where(firstname: parts.first, lastname: parts.last).limit(LIMIT).ids
    end
    ids += base.where("participant_code ILIKE ?", ilike).limit(LIMIT).ids

    Group.new(type: :patients, records: base.where(id: ids.uniq.first(LIMIT)).to_a)
  end

  def cities_group
    return unless can_show?(City)

    cities = city_scope.where("name ILIKE ?", ilike).distinct.order(:name).limit(LIMIT)
    results = cities.map do |city|
      CityResult.new(city: city, studies: studies_in_city(city))
    end
    Group.new(type: :cities, records: results)
  end

  # ---- Scopes (admin = all, rep = own branch, else = permitted rows) ----

  def study_scope
    return Study.all if admin?
    return branch ? branch.studies : Study.none if user.trial_center_branch_rep?

    Study.all
  end

  def branch_scope
    return TrialCenterBranch.all if admin?
    return branch ? TrialCenterBranch.where(id: branch.id) : TrialCenterBranch.none if user.trial_center_branch_rep?

    TrialCenterBranch.all
  end

  def facility_scope
    return TrialCenterFacility.all if admin?
    return branch ? TrialCenterFacility.where(id: branch.trial_center_facility_id) : TrialCenterFacility.none if user.trial_center_branch_rep?

    TrialCenterFacility.all
  end

  def branch_rep_scope
    return TrialCenterBranchRep.all if admin?
    return branch ? TrialCenterBranchRep.where(trial_center_branch_id: branch.id) : TrialCenterBranchRep.none if user.trial_center_branch_rep?

    TrialCenterBranchRep.all
  end

  def city_scope
    return City.all if admin?
    return branch ? branch.cities : City.none if user.trial_center_branch_rep?

    City.all
  end

  # Studies that run in `city` — i.e. studies of the branches located in that
  # city — narrowed to what this user may see (their own branch, for a rep).
  def studies_in_city(city)
    study_scope
      .joins(:trial_center_branches)
      .where(trial_center_branches: { id: city.trial_center_branch_ids })
      .distinct.order(:public_title).limit(LIMIT).to_a
  end

  def reps_matching(scope)
    scope.joins(:user)
         .where(
           "users.firstname ILIKE :q OR users.lastname ILIKE :q OR users.email ILIKE :q " \
           "OR (users.firstname || ' ' || users.lastname) ILIKE :q",
           q: ilike
         )
         .limit(LIMIT).to_a
  end

  # ---- Helpers ----

  def admin?
    user.admin?
  end

  def branch
    return @branch if defined?(@branch)

    @branch = user.trial_center_branch_rep? ? user.userable&.trial_center_branch : nil
  end

  def can_show?(model)
    user.role&.permits?(model, :can_show)
  end

  # LIKE pattern with the user's wildcards escaped, wrapped for a contains match.
  def ilike
    "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
  end
end
