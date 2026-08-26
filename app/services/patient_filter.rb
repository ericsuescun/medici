# Turns the recruitment index's query string into a narrowed patient relation,
# and offers the lists that populate its selects.
#
# TWO RULES GOVERN THIS CLASS.
#
# 1. It only ever narrows. It is handed a relation that PatientPolicy::Scope has
#    already reduced to the patients this user may see, and every filter is an
#    additional `where`. Nothing here can widen that set, so a crafted query
#    string cannot reach another sponsor's or another centre's patients.
#
# 2. The select options come from that same scoped relation, never from
#    `Study.all` / `Sponsor.all`. A dropdown listing every sponsor in the country
#    would disclose who else is running trials here even if picking one returned
#    no rows — the existence of the option is itself the leak.
#
# City means the city of the trial centre, reached through the branches that run
# the study (City ↔ TrialCenterBranch ↔ Study) — NOT `Study#trial_cities`, which
# is a different, study-owned thing. `reported_city` is a separate filter: it is
# what the patient said about themselves on the public form, which is what you
# want when deciding where to recruit rather than where to treat.
class PatientFilter
  # Filters resolved in SQL. `recommendation` is deliberately absent — it is
  # computed per patient by EligibilityResult and cannot be expressed as a WHERE;
  # the controller applies it in Ruby after loading, and says so.
  PERMITTED = %i[state study_id sponsor_id city_id trial_center_branch_id reported_city questionnaire identity].freeze

  QUESTIONNAIRE_VALUES = %w[with without].freeze

  # "lead" = arrived through the public form, so no name — see Patient.leads.
  IDENTITY_VALUES = %w[lead named].freeze

  attr_reader :filters

  # `base` is the policy-scoped relation. `allowed_states` bounds the state
  # filter so the recruitment page cannot be talked into rendering participants
  # through `?state=participant`, and vice versa.
  def initialize(base, params, allowed_states:)
    @base = base
    @allowed_states = allowed_states.map(&:to_s)
    @filters = normalize(params)
  end

  def results
    scoped = @base
    scoped = scoped.where(state: filters[:state]) if filters[:state]
    scoped = scoped.where(study_id: filters[:study_id]) if filters[:study_id]

    # Sponsor, city and branch are all predicates about the STUDY, so they are
    # applied as `study_id IN (...)`. Joining `study: { trial_center_branches:
    # :cities }` onto the patient relation instead would multiply a patient into
    # one row per matching branch, and the DISTINCT needed to repair that breaks
    # the CASE ordering in Patient.in_review_order.
    scoped = scoped.where(study_id: studies_of_sponsor) if filters[:sponsor_id]
    scoped = scoped.where(study_id: studies_in_city) if filters[:city_id]
    scoped = scoped.where(study_id: studies_at_branch) if filters[:trial_center_branch_id]

    scoped = scoped.where(reported_city: filters[:reported_city]) if filters[:reported_city]
    scoped = apply_questionnaire(scoped) if filters[:questionnaire]
    scoped = filters[:identity] == "lead" ? scoped.leads : scoped.named if filters[:identity]

    scoped
  end

  def any?
    filters.any?
  end

  def only_leads?
    filters[:identity] == "lead"
  end

  # Counted against the base relation, not the filtered one, so the badge says
  # how many leads there are to look at rather than how many survived the
  # filters currently applied.
  def leads_count
    @leads_count ||= @base.leads.count
  end

  # ---- Select options, all derived from the scoped relation ----

  def studies
    @studies ||= Study.where(id: study_ids).order(:public_title, :short_title)
  end

  def sponsors
    @sponsors ||= Sponsor.where(id: Study.where(id: study_ids).select(:sponsor_id)).order(:name)
  end

  def cities
    @cities ||= City.joins(trial_center_branches: :studies)
                    .where(studies: { id: study_ids })
                    .distinct
                    .order(:name)
  end

  def trial_center_branches
    @trial_center_branches ||= TrialCenterBranch.joins(:studies)
                                                .where(studies: { id: study_ids })
                                                .distinct
                                                .order(:name)
  end

  # Plaintext and coarse (a picker of Patient::PRINCIPAL_CITIES), so unlike the
  # encrypted fields it can be grouped and offered as options.
  def reported_cities
    @reported_cities ||= @base.where.not(reported_city: [ nil, "" ])
                              .distinct
                              .pluck(:reported_city)
                              .sort
  end

  private

  def study_ids
    @study_ids ||= @base.select(:study_id)
  end

  def studies_of_sponsor
    Study.where(sponsor_id: filters[:sponsor_id]).select(:id)
  end

  def studies_in_city
    Study.joins(trial_center_branches: :cities).where(cities: { id: filters[:city_id] }).select(:id)
  end

  def studies_at_branch
    Study.joins(:trial_center_branches)
         .where(trial_center_branches: { id: filters[:trial_center_branch_id] })
         .select(:id)
  end

  def apply_questionnaire(scoped)
    answered = PatientDeclaration.live.select(:patient_id)

    filters[:questionnaire] == "with" ? scoped.where(id: answered) : scoped.where.not(id: answered)
  end

  # Blank values drop out entirely, so "" behaves like "no filter" rather than
  # matching nothing. Unknown states are dropped instead of raising: a stale
  # bookmark should show the unfiltered page, not an error.
  def normalize(params)
    given = params.to_h.symbolize_keys.slice(*PERMITTED)
    given = given.reject { |_, value| value.blank? }

    given.delete(:state) unless @allowed_states.include?(given[:state].to_s)
    given.delete(:questionnaire) unless QUESTIONNAIRE_VALUES.include?(given[:questionnaire].to_s)
    given.delete(:identity) unless IDENTITY_VALUES.include?(given[:identity].to_s)
    given
  end
end
