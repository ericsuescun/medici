# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  adult_confirmed     :boolean          default(FALSE), not null
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :string
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  participant_code    :string
#  reported_city       :string
#  self_registered     :boolean          default(FALSE), not null
#  sex                 :string
#  state               :string           default("interested"), not null
#  submitted_by_proxy  :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  study_id            :bigint
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_self_registered   (self_registered)
#  index_patients_on_state             (state)
#  index_patients_on_study_id          (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
class Patient < ApplicationRecord
  include Userable

  # Backs the habeas-data checkbox on the public participation form. Not a
  # column: what was agreed is persisted as an immutable Consent record, never
  # as a mutable boolean on the patient.
  attr_accessor :data_processing_authorization

  # Pseudonymization (INVIMA Anexo Técnico Tabla 7): the patient owns its own
  # identity/clinical columns (it does NOT delegate identity to the shared User —
  # see DelegatesIdentityToUser), and those columns are encrypted at rest.
  #
  # Deterministic for the fields we search/look a patient up by (exact-match
  # queries + unique-ish identifiers); non-deterministic (stronger) for free-text
  # clinical data we never query by value. Patient#email is NOT the Devise login
  # (that stays on User), so encrypting it here has no auth impact.
  ENCRYPTED_DETERMINISTIC = %i[firstname lastname email dob contact_number contact_address id_number].freeze
  ENCRYPTED_NON_DETERMINISTIC = %i[illness_description notes].freeze

  # dob is stored as a string column (ciphertext can't live in a date column) but
  # still behaves as a Date in Ruby.
  attribute :dob, :date

  encrypts(*ENCRYPTED_DETERMINISTIC, deterministic: true)
  encrypts(*ENCRYPTED_NON_DETERMINISTIC)

  # Audit trail for AASM state changes and non-sensitive attributes. Skip the
  # encrypted fields so their plaintext is never copied into the versions table
  # (which lives in the same database) — the audit log must not defeat encryption.
  has_paper_trail skip: (ENCRYPTED_DETERMINISTIC + ENCRYPTED_NON_DETERMINISTIC)

  has_many :variable_values, dependent: :destroy

  # Self-reported testimony (public questionnaire or rep-transcribed) — kept
  # apart from variable_values, the investigator-verified measurements.
  has_many :patient_declarations, dependent: :destroy

  # Files the patient attached on the public questionnaire ("exams you already
  # have") — named so their provenance stays legible next to the staff-curated
  # ComplementaryInformation bundle. Server-side attach only: the Active Storage
  # direct-upload endpoint stays login-gated.
  has_many_attached :self_reported_files

  SELF_REPORTED_FILE_TYPES = (%w[application/pdf] +
    %w[image/png image/jpeg image/webp image/heic image/heif]).freeze
  MAX_SELF_REPORTED_FILES = 5
  MAX_SELF_REPORTED_FILE_SIZE = 25.megabytes

  validate :self_reported_files_within_limits

  # Cities offered on the public questionnaire ("¿En qué ciudad vive?") —
  # principal cities, plus "Otra" as the catch-all. The picker is the source of
  # truth for location; IP geolocation (unreliable on Colombian mobile CGNAT)
  # is at most a future prefill, never the datum.
  PRINCIPAL_CITIES = [
    "Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena", "Bucaramanga",
    "Cúcuta", "Pereira", "Santa Marta", "Ibagué", "Manizales", "Villavicencio"
  ].freeze

  # Patient-contributed complementary information (prior exams: PDFs, images, notes).
  has_one :complementary_information, dependent: :destroy

  # A patient exists to be considered for one study. This used to live on the
  # patient's User account (User has_and_belongs_to_many :studies) because a
  # patient could only be created by signing up; patients are records now, so the
  # study belongs to the patient.
  belongs_to :study

  # The habeas-data authorizations this patient granted (Ley 1581 de 2012).
  has_many :consents, dependent: :destroy

  # A non-identifying code linking research/eligibility data back to the patient
  # by code rather than identity.
  before_create :assign_participant_code
  validates :participant_code, uniqueness: true, allow_nil: true

  # Neither contact field is mandatory on its own — a prospective patient may
  # leave a phone, an email, or both. But a lead with no way to reach them is
  # useless: the whole point is that a centre rep calls them back.
  validate :some_way_to_make_contact

  def fullname
    [ firstname, lastname ].compact_blank.join(" ")
  end

  # What to show wherever a patient is named in the UI. A patient who arrived
  # through the public participation form has NO name yet — that form takes a
  # phone/email and nothing else — so `fullname` is blank for every lead, and a
  # view that renders it raw produces an empty cell (and, if it is a link, an
  # unclickable one). The participant code is the stable, plaintext, non-
  # identifying handle that always exists, so it is the fallback.
  #
  # This used to be written out as `fullname.presence || participant_code` at
  # ten separate call sites; the study page was the one that forgot, which is
  # exactly the divergence a shared method prevents.
  def display_name
    fullname.presence || participant_code
  end

  # Patients whose study runs at one of `branches` — the scoping rule for a
  # trial centre rep, who must only ever see the patients of their own centre.
  #
  # Expressed as `study_id IN (...)` rather than a join + DISTINCT. A study runs
  # at many branches, so joining multiplies a patient into one row per branch,
  # and the DISTINCT that repaired that then collided with the CASE ordering
  # below (Postgres: "for SELECT DISTINCT, ORDER BY expressions must appear in
  # select list"). A subquery cannot multiply rows, so neither problem exists.
  scope :for_trial_center_branches, ->(branches) {
    where(study_id: Study.joins(:trial_center_branches)
                         .where(trial_center_branches: { id: branches })
                         .select(:id))
  }

  # Patients whose study belongs to one of `sponsors` — the scoping rule for a
  # sponsor rep. A sponsor must never see another sponsor's patients, so this is
  # the sponsor-side twin of the scope above; PatientPolicy::Scope applies it.
  scope :for_sponsors, ->(sponsors) {
    where(study_id: Study.where(sponsor_id: sponsors).select(:id))
  }

  # The pipeline the recruitment index works: everybody who has not yet joined a
  # trial. `potential` is deliberately NOT here — those are results, not work,
  # and they get their own page (PatientsController#potentials).
  RECRUITING_STATES = %w[interested candidate].freeze
  FINAL_STATE = "potential"

  # Patients who registered THEMSELVES through the public form — as opposed to
  # the ones a rep typed in. For a rep this is the "nobody has called these
  # people yet" list, and it is the one worth working first: they raised their
  # hand minutes ago.
  #
  # Recorded as a column rather than inferred. It used to be inferred from a
  # blank `firstname`, which worked only because the public form could not ask
  # for a name; now that it can (2026-10-04), the inference would have quietly
  # dropped every self-registered patient who actually typed one — the most
  # engaged ones — out of the list a rep works from.
  #
  # `display_name` still falls back to the participant code, because the name
  # stays OPTIONAL on that form: somebody who will leave a phone number but not
  # a name is still a lead worth calling.
  scope :leads, -> { where(self_registered: true) }
  scope :staff_entered, -> { where(self_registered: false) }

  scope :recruiting, -> { where(state: RECRUITING_STATES) }
  scope :potentials, -> { where(state: FINAL_STATE) }

  # Review order: candidates first (they asked for the rep's attention — many
  # arrive auto-triaged from their own questionnaire answers), then interested,
  # then potentials. Lived in PatientsController as a Ruby sort key; it is a
  # property of the lifecycle, not of one page, and expressing it in SQL means a
  # relation is already in review order before anything materialises it.
  STATE_REVIEW_ORDER = { "candidate" => 0, "interested" => 1, FINAL_STATE => 2 }.freeze

  scope :in_review_order, -> {
    whens = STATE_REVIEW_ORDER.map { |state, rank| "WHEN #{connection.quote(state)} THEN #{rank}" }

    order(Arel.sql("CASE #{table_name}.state #{whens.join(' ')} ELSE 9 END"), created_at: :desc)
  }

  # This patient evaluated against their study's eligibility rules, or nil when
  # the study has no criteria profile. Memoized per instance: an evaluation costs
  # two association reads, and the AASM guard below runs once per rendered row on
  # the patients index.
  def eligibility_result
    return @eligibility_result if defined?(@eligibility_result)

    @eligibility_result = study&.criteria_profile&.evaluate(self)
  end

  # Drop the memoized evaluations on reload. Without this, re-reading a patient
  # after capturing values (or after a rule changed) would still answer with the
  # verdict from before — and those verdicts gate state transitions.
  def reload(*)
    remove_instance_variable(:@eligibility_result) if defined?(@eligibility_result)
    remove_instance_variable(:@self_report_result) if defined?(@self_report_result)
    super
  end

  # The patient's DECLARATIONS evaluated against the same rules — the triage
  # tier's evidence. Memoized like eligibility_result, invalidated by #reload.
  def self_report_result
    return @self_report_result if defined?(@self_report_result)

    @self_report_result = study&.criteria_profile&.evaluate_self_reports(self)
  end

  # The forward step available from the current state, or nil at the end of the
  # line. Paired with FORWARD_EVENT_CHECKS below.
  FORWARD_EVENTS = { "interested" => "assess", "candidate" => "accept" }.freeze

  # Which evidence tier gates each forward event — the TWO-TIER rule, in one
  # place. `assess` (triage) opens on investigator values OR the patient's own
  # declarations; `accept` (clinical) opens on investigator values only.
  #
  # This lived in PatientsController while three views hardcoded
  # `!basic_criteria_met?` for BOTH events, so an `interested` patient who
  # qualified only by self-report rendered a disabled "locked" button next to a
  # working one. Anything asking "do the criteria permit the next step" must go
  # through `criteria_permit_forward?` rather than pick a predicate itself.
  FORWARD_EVENT_CHECKS = {
    "assess" => :criteria_met_for_candidate?,
    "accept" => :criteria_met_for_potential?
  }.freeze

  # The step BACK available from the current state, or nil at the start of the
  # line. Never gated — see the aasm block — but a patient at the END of the
  # line has only this, and the take-action copy has to be able to name it:
  # offering promotion advice to a patient at `potential` is what made the box read as
  # "reject this patient" (fixed 2026-08-25).
  BACKWARD_EVENTS = { "candidate" => "discard", "potential" => "reject" }.freeze

  def forward_event
    FORWARD_EVENTS[state]
  end

  def backward_event
    BACKWARD_EVENTS[state]
  end

  # The state an event lands in from where the patient stands now. Read off the
  # AASM machine rather than kept as a second hardcoded map, so the copy the rep
  # reads on the button ("promover de Candidato a Potencial") cannot describe
  # a transition the machine no longer makes.
  def target_state_for(event)
    return nil if event.blank?

    aasm.events.find { |e| e.name.to_s == event.to_s }
        &.transitions&.find { |t| t.from.to_s == state }&.to&.to_s
  end

  def forward_target_state
    target_state_for(forward_event)
  end

  def backward_target_state
    target_state_for(backward_event)
  end

  # True when the criteria do not stand in the way of the next forward step —
  # evaluated at the tier that step actually requires. True at the end of the
  # lifecycle, where there is no next step to gate.
  def criteria_permit_forward?
    check = FORWARD_EVENT_CHECKS[forward_event]

    check.nil? || public_send(check)
  end

  # The basic tier, investigator half: every BASIC criterion has a recorded
  # VariableValue and all of them comply (inclusions met, exclusions not met).
  # Unmeasured is not compliance — a rep has to actually record the value.
  #
  # Specific criteria are deliberately not consulted here: they are the OTHER
  # tier, gating the next step (see #criteria_met_for_potential?), not this one.
  #
  # True when the study has no criteria profile, or the profile marks nothing
  # basic: there is nothing decisive to check, so nothing to block on.
  def basic_criteria_met?
    result = eligibility_result

    result.nil? || result.basic_criteria_met?
  end

  # The triage tier: the patient's own declarations satisfy every basic
  # criterion. Deliberately weaker evidence for a deliberately weaker claim —
  # "worth a rep's review", never "fit to participate". Unlike the clinical
  # tier there is NO fail-open here: with no profile, no basic criteria, or
  # no declarations there is no self-reported evidence, so this is false and
  # triage falls back to the clinical tier's judgment.
  def basic_criteria_met_by_self_report?
    result = self_report_result

    !result.nil? && result.basic_total_count.positive? && result.promotable?
  end

  # Guard for interested → candidate (triage): investigator-verified values OR
  # the patient's own declarations open it. Candidate honestly means "worth a
  # rep's look" — which self-reported answers can establish.
  def criteria_met_for_candidate?
    basic_criteria_met? || basic_criteria_met_by_self_report?
  end

  # Guard for candidate → potential (clinical). BOTH tiers, and investigator
  # values only on both — `basic_criteria_met?` reads `eligibility_result`,
  # which is built from VariableValues, so a patient who reached `candidate` on
  # their own testimony cannot go further until a rep has actually measured the
  # basic criteria too. That re-measurement IS the review this step exists for.
  #
  # The specific half is vacuously true when the profile defines no specific
  # criteria (nothing to check, nothing to block on), the same fail-open the
  # basic half has; it is the basic half that keeps self-report out.
  def criteria_met_for_potential?
    result = eligibility_result

    result.nil? || (result.basic_criteria_met? && result.specific_criteria_met?)
  end

  # Attribution for an automatic move. Deliberately the system even when a rep's
  # save is what triggered the sync: the rep recorded a measurement, they did
  # not decide to promote anybody, and a version signed with their name would
  # claim they did. Same reasoning as the self-report triage whodunnit.
  SYSTEM_WHODUNNIT = "system:criteria-sync".freeze

  # Forward steps the system may take on its own — `assess` ONLY.
  #
  # Reaching `candidate` is a filing decision: it says "this one is worth a
  # rep's time", and making the rep click to agree with arithmetic they can
  # already see adds nothing. Reaching `potential` is not. It says the centre
  # has a patient it can approach about a trial, and the whole point of the
  # candidate stage is that a human reads the record first — much of which
  # arrived as the patient's own unverified testimony. So `accept` stays a
  # click, with both tiers guarding it; what automation owes the rep there is
  # ordering the queue so the ready ones are on top, not pressing the button.
  AUTO_FORWARD_EVENTS = %w[assess].freeze

  # Three states, so no sync can need more than two steps; the cap is a backstop
  # against a future state being added without revisiting this loop.
  MAX_SYNC_STEPS = 4

  # Where the recorded evidence says this patient should stand, applied.
  #
  # The ONE place a patient moves without a rep pressing a button. Called after
  # any change to the evidence — a rep saving the assessment form, a patient
  # submitting the questionnaire. Demotion is evaluated BEFORE promotion: a
  # criterion that now measurably fails outranks everything that still passes.
  # Each step is a real AASM event, so each one is guarded, versioned and
  # visible in the patient's history — never a write to the state column.
  def sync_state_with_criteria!
    reload

    PaperTrail.request(whodunnit: SYSTEM_WHODUNNIT) do
      MAX_SYNC_STEPS.times do
        if criteria_demotion_target
          public_send("#{BACKWARD_EVENTS.fetch(state)}!")
        elsif AUTO_FORWARD_EVENTS.include?(forward_event) && criteria_permit_forward? && auto_promotable?
          public_send("#{forward_event}!")
        else
          break
        end
      end
    end
  end

  # Positive evidence that the step is earned — deliberately stricter than the
  # AASM guard beside it.
  #
  # The guard fails OPEN when a study has no criteria profile, or none in the
  # tier: with no rule to check there is nothing to hold anybody back, which is
  # the right answer to "may a rep do this". It is the wrong answer to "should
  # the system do it unasked" — a study whose profile nobody has written yet
  # would have every one of its patients filed as a candidate on the strength
  # of no evidence whatsoever. Automation therefore requires a rule that exists
  # AND is satisfied; the button keeps the fail-open.
  def auto_promotable?
    basic_criteria_measured_and_met? || basic_criteria_met_by_self_report?
  end

  def basic_criteria_measured_and_met?
    result = eligibility_result

    !result.nil? && result.basic_total_count.positive? && result.basic_criteria_met?
  end

  # The state a MEASURED failure drags this patient back to, or nil when nothing
  # recorded contradicts where they stand.
  #
  # Three deliberate restrictions. Only `eligibility_result` is consulted, so a
  # patient's own testimony can never demote them — a rep who disbelieves a
  # declaration presses Descartar, and that stays a human act. Only `:fail`
  # counts, never `:missing`, so adding a criterion to a profile does not demote
  # every patient on the study the moment it is saved. And a failing specific
  # criterion only reaches back as far as `candidate`: it gates the step into
  # `potential`, so that is the step it can undo.
  def criteria_demotion_target
    result = eligibility_result
    return nil if result.nil? || state == "interested"
    return "interested" if result.basic_failing.any?
    return "candidate" if state == FINAL_STATE && result.specific_failing.any?

    nil
  end

  include AASM

  aasm column: :state do
    state :interested, initial: true
    state :candidate
    state :potential

    # Forward steps are guarded by TWO TIERS, for two different claims.
    #
    # `assess` (interested → candidate) asks the BASIC criteria only, and will
    # take the patient's own declarations as evidence: "candidate" claims no
    # more than "worth a rep's look", which a questionnaire can establish. It
    # is the one step the system takes by itself (see AUTO_FORWARD_EVENTS).
    #
    # `accept` (candidate → potential) asks BOTH tiers and will only read
    # investigator-recorded values, on both. So a patient can self-report their
    # way onto the review list and no further; the measurement a rep has to do
    # to open this step is exactly the review the candidate stage exists for.
    #
    # The guards live here rather than in the controller so no code path can
    # skip them — and because PatientPolicy#assess?/#accept? delegate to AASM's
    # `may_*?`, they propagate to the policy and every view for free.
    event :assess do
      transitions from: :interested, to: :candidate, guard: :criteria_met_for_candidate?
    end

    event :accept do
      transitions from: :candidate, to: :potential, guard: :criteria_met_for_potential?
    end

    # Backward steps are never gated — walking a patient back must always be
    # possible, especially when the criteria are what went wrong.
    event :discard do
      transitions from: :candidate, to: :interested
    end

    event :reject do
      transitions from: :potential, to: :candidate
    end
  end

  private

  def some_way_to_make_contact
    return if contact_number.present? || email.present?

    errors.add(:base, I18n.t("patients.contact_method_required"))
  end

  def self_reported_files_within_limits
    return unless self_reported_files.attached?

    if self_reported_files.count > MAX_SELF_REPORTED_FILES
      errors.add(:base, I18n.t("self_reports.errors.too_many_files", limit: MAX_SELF_REPORTED_FILES))
    end

    self_reported_files.each do |file|
      unless SELF_REPORTED_FILE_TYPES.include?(file.blob.content_type)
        errors.add(:base, I18n.t("self_reports.errors.bad_file_type", filename: file.blob.filename))
      end
      if file.blob.byte_size > MAX_SELF_REPORTED_FILE_SIZE
        errors.add(:base, I18n.t("self_reports.errors.file_too_large",
                                 filename: file.blob.filename,
                                 limit: MAX_SELF_REPORTED_FILE_SIZE / 1.megabyte))
      end
    end
  end

  def assign_participant_code
    return if participant_code.present?

    self.participant_code = loop do
      candidate = "P-#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless Patient.exists?(participant_code: candidate)
    end
  end
end
