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
  scope :for_trial_center_branches, ->(branches) {
    joins(study: :trial_center_branches)
      .where(trial_center_branches: { id: branches })
      .distinct
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
  # `!primary_criteria_met?` for BOTH events, so an `interested` patient who
  # qualified only by self-report rendered a disabled "locked" button next to a
  # working one. Anything asking "do the criteria permit the next step" must go
  # through `criteria_permit_forward?` rather than pick a predicate itself.
  FORWARD_EVENT_CHECKS = {
    "assess" => :primary_criteria_met_for_triage?,
    "accept" => :primary_criteria_met?
  }.freeze

  def forward_event
    FORWARD_EVENTS[state]
  end

  # True when the criteria do not stand in the way of the next forward step —
  # evaluated at the tier that step actually requires. True at the end of the
  # lifecycle, where there is no next step to gate.
  def criteria_permit_forward?
    check = FORWARD_EVENT_CHECKS[forward_event]

    check.nil? || public_send(check)
  end

  # The clinical tier: every PRIMARY criterion has an investigator-recorded
  # VariableValue and all of them comply (inclusions met, exclusions not met).
  # Unmeasured is not compliance — a rep has to actually record the value.
  #
  # Secondary criteria are deliberately not consulted. Whether an unmet
  # complementary criterion should stop a patient is the rep's clinical
  # judgment; they express it by making or withholding the transition, and
  # PaperTrail records who did it and when.
  #
  # True when the study has no criteria profile, or the profile marks nothing
  # primary: there is nothing decisive to check, so nothing to block on.
  def primary_criteria_met?
    result = eligibility_result

    result.nil? || result.permits_promotion?
  end

  # The triage tier: the patient's own declarations satisfy every primary
  # criterion. Deliberately weaker evidence for a deliberately weaker claim —
  # "worth a rep's review", never "fit to participate". Unlike the clinical
  # tier there is NO fail-open here: with no profile, no primary criteria, or
  # no declarations there is no self-reported evidence, so this is false and
  # triage falls back to the clinical tier's judgment.
  def primary_criteria_met_by_self_report?
    result = self_report_result

    !result.nil? && result.primary_total_count.positive? && result.promotable?
  end

  # Guard for interested → candidate (triage): investigator-verified values OR
  # the patient's own declarations open it. Candidate honestly means "worth a
  # rep's look" — which self-reported answers can establish.
  def primary_criteria_met_for_triage?
    primary_criteria_met? || primary_criteria_met_by_self_report?
  end

  include AASM

  aasm column: :state do
    state :interested, initial: true
    state :candidate
    state :participant

    # Forward steps are guarded, but by TWO TIERS OF EVIDENCE for two tiers of
    # claim: `assess` (triage — the patient is worth reviewing) accepts
    # self-reported declarations; `accept` (clinical — the patient joins the
    # trial) requires investigator-verified values ONLY. A patient can
    # self-report their way onto the rep's review list, never into the trial.
    # The guards live here rather than in the controller so no code path can
    # skip them — and because PatientPolicy#assess?/#accept? delegate to AASM's
    # `may_*?`, they propagate to the policy and every view for free.
    event :assess do
      transitions from: :interested, to: :candidate, guard: :primary_criteria_met_for_triage?
    end

    event :accept do
      transitions from: :candidate, to: :participant, guard: :primary_criteria_met?
    end

    # Backward steps are never gated — walking a patient back must always be
    # possible, especially when the criteria are what went wrong.
    event :discard do
      transitions from: :candidate, to: :interested
    end

    event :reject do
      transitions from: :participant, to: :candidate
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
