# Step 2 of the public participation flow: right after leaving contact details
# (and granting the Ley 1581 authorization), the patient answers as many of the
# study's patient-language questions as they can, in the SAME browser session.
#
# TWO PAGES (since 2026-10-06), in the order the criteria gate the lifecycle:
#
#   1. `show`/`create` — the BASIC questions, plus everything that is not a
#      criterion (city, files, the optional future-studies consent). Submitting
#      it is what can triage the patient to `candidate`.
#   2. `more`/`create_more` — the SPECIFIC questions. Only for a patient the
#      basic answers keep in the running. Somebody they rule out, or who left
#      them unanswered, finishes after page 1: no specific answer could change
#      their outcome for this study, and Decreto 1377 de 2013 Art. 4 limits
#      collection to data "pertinentes y adecuados para la finalidad". That is
#      also why everything that is not a criterion lives on page 1 — the city and
#      the future-studies consent matter most to exactly the people who stop
#      there, and their exams can still answer a basic question they could not.
#
# No account, no token, no link — the identity is the session: step 1 stamps
# the freshly-created patient's id into the (encrypted) session with an expiry,
# and this controller only ever reads it from there, never from params, so
# there is nothing to enumerate or forward. The stamp also records which page
# the patient is on, so each page is submitted exactly once and the back button
# leads forward rather than to a second attempt. Inherits ApplicationController
# (public), like ParticipationRequestsController.
#
# What the patient sees is ONLY each rule's patient_prompt — never the rule
# name, thresholds or rule_summary (those describe the protocol). What they
# submit lands in patient_declarations (testimony), NEVER variable_values (the
# investigator-verified gate inputs). If the declarations satisfy every basic
# criterion, the patient is auto-triaged interested → candidate with a system
# whodunnit — that is the triage tier only; joining the trial still requires
# investigator-verified values (see Patient's AASM guards).
#
# The confirmation page never echoes a CRITERION ("no cumples por tu edad",
# per-answer pass/fail, thresholds, progress bars) — that is a clinical
# communication the investigator owns, and naming a criterion would turn the
# form into an oracle a patient could optimise against. Permanent constraint.
#
# It DOES say, since 2026-08-25, whether the study looks like a match at all:
# answering into silence left people with nothing, which is its own harm. That
# is a deliberate, bounded relaxation and the bound is what makes it safe:
#
#   * One bit, and no reason. "Por ahora no parece corresponder" covers a
#     measurable failure and an incomplete questionnaire identically, so it does
#     not even say WHICH of the two happened. Reaching page 2 carries the same
#     bit and nothing more, read off the same answers.
#   * Once. Page 1 cannot be resubmitted after it has been answered, so the bit
#     cannot be probed by going back and trying other answers.
#   * The bit buys nothing worth having. Brute-forcing it reaches `candidate`,
#     the TRIAGE tier — joining the trial still requires investigator-verified
#     values (Patient's AASM guards), so the ceiling is a wasted phone call.
#
# The exclusions themselves are shown UPFRONT instead, to everybody, before any
# question is answered (see the view). Stating them is standard recruitment
# practice and honest self-selection; it is not feedback, so it is not an oracle.
class SelfReportsController < ApplicationController
  SESSION_KEY = "self_report".freeze
  SESSION_TTL = 2.hours
  # The page the stamp says the patient is on. A stamp written before the pages
  # split has no stage, which reads as the first.
  SPECIFIC_STAGE = "specific".freeze

  before_action :set_patient_from_session
  before_action :set_study_and_questions
  before_action :require_basic_stage, only: %i[show create]
  before_action :require_specific_stage, only: %i[more create_more]

  def show
    @declarations_by_variable = live_declarations
  end

  # Page 1. All or nothing: until 2026-10-06 the declarations were written
  # before the files were validated, so a rejected submission (six files, over
  # the cap) left health testimony stored with no self-report consent beside it
  # — and that orphaned testimony could still triage the patient.
  def create
    saved = Patient.transaction do
      save_declarations!(@basic_questions)
      attach_files!
      update_patient_extras!
      raise ActiveRecord::Rollback unless @patient.valid?

      @patient.save!
      # The submission is the authorization for processing what it contains
      # (Decreto 1377 Art. 7 conductas inequívocas; the page states the purpose).
      Consent.record_self_report!(@patient, ip_address: request.remote_ip)
      # The future-studies authorization is separate and OPTIONAL — participation
      # is never conditioned on it (Decreto 1377 Art. 6).
      Consent.record_future_studies!(@patient, ip_address: request.remote_ip) if future_studies_authorized?
      true
    end

    unless saved
      # Rolled back, so the answers are re-rendered from what was just typed.
      @declarations_by_variable = submitted_declarations(@basic_questions)
      render :show, status: :unprocessable_entity and return
    end

    auto_triage!

    # Read AFTER auto_triage! so it reflects the same evaluation the guard used.
    # `basic_criteria_met_by_self_report?` is false both for "measurably does
    # not qualify" and for "did not answer enough", which is deliberate: the
    # patient is told the study is not a match without being told why, and
    # without the two cases being distinguishable from outside.
    looks_like_a_match = @patient.reload.basic_criteria_met_by_self_report?

    if ask_specific?(looks_like_a_match)
      session[SESSION_KEY] = session[SESSION_KEY].merge("stage" => SPECIFIC_STAGE)
      redirect_to study_self_report_more_path(@study)
    else
      finish!(looks_like_a_match)
    end
  end

  def more
    @declarations_by_variable = live_declarations
  end

  # Page 2. Nothing here can move the patient — specific declarations are
  # testimony, and the step they gate reads investigator values only — but the
  # sync still runs, because it runs after every change to the evidence.
  def create_more
    Patient.transaction do
      save_declarations!(@specific_questions)
      Consent.record_self_report!(@patient, ip_address: request.remote_ip)
    end
    auto_triage!

    finish!(@patient.reload.basic_criteria_met_by_self_report?)
  end

  private

  # The basic EXCLUSIONS, shown before any question is answered. Only
  # exclusions: those are the ones that keep somebody out of a trial that could
  # harm them, and they are the ones a person can check against themselves
  # without a clinic. Inclusions stay unlisted — "you must be 18 to 75" is a
  # threshold, and thresholds are protocol. Only basic ones: a prompted specific
  # exclusion is asked on page 2, and this list is meant to be the few decisive
  # facts, read before anything else.
  def upfront_exclusions
    @basic_questions.select(&:exclusion?)
  end
  helper_method :upfront_exclusions

  # Whether page 1 leads on to page 2. A patient the basic answers rule out
  # stops here (see the header). A profile with no askable basic question has
  # nothing to rule anybody out on, so its patients go straight on — otherwise
  # its specific questions could never be asked at all.
  def ask_specific?(looks_like_a_match)
    @specific_questions.any? && (looks_like_a_match || @basic_questions.empty?)
  end

  # The end of the questionnaire, from either page: the stamp is spent, and the
  # patient lands on the study page with the one bit.
  def finish!(looks_like_a_match)
    session.delete(SESSION_KEY)
    # Both events: step 1 created the lead but redirected here, to a page that
    # carries no tags, so this is the first measured page since. Reporting both
    # keeps lead counts the same whichever path the visitor took.
    flash[:analytics_events] = %w[participation_submitted self_report_completed]
    redirect_to study_about_path(@study),
                notice: t(looks_like_a_match ? "self_reports.thanks" : "self_reports.not_a_match")
  end

  # The patient comes from the session stamp step 1 wrote — never from params.
  # Anything off (no stamp, expired, patient gone) is a plain redirect home;
  # a generic response that confirms nothing.
  def set_patient_from_session
    stamp = session[SESSION_KEY]
    expire! and return if stamp.blank?
    expire! and return if stamp["expires_at"].blank? || Time.zone.parse(stamp["expires_at"]) < Time.current

    @patient = Patient.find_by(id: stamp["patient_id"])
    expire! if @patient.nil?
  end

  def set_study_and_questions
    return if performed?

    @study = @patient.study
    # The switch means "this study's question wording is approved participant
    # material" — off, or nothing askable, and there is no step 2 at all.
    expire! and return unless @study&.patient_self_report_enabled?

    questions = @study.criteria_profile&.criteria_variables&.askable_to_patient
                      &.sort_by { |cv| cv.criteria_order || 0 } || []
    expire! and return if questions.empty?

    @basic_questions, @specific_questions = questions.partition(&:basic?)
  end

  # The back button from page 2 lands here; send it forward, not into a second
  # attempt at page 1.
  def require_basic_stage
    redirect_to study_self_report_more_path(@study) if stage == SPECIFIC_STAGE
  end

  def require_specific_stage
    redirect_to study_self_report_path(@study) unless stage == SPECIFIC_STAGE
  end

  def stage
    session.dig(SESSION_KEY, "stage")
  end

  def expire!
    session.delete(SESSION_KEY)
    redirect_to root_path
  end

  def live_declarations
    @patient.patient_declarations.live.index_by(&:criteria_variable_id)
  end

  # What was typed, unsaved, so a rejected page can be shown again as it was.
  def submitted_declarations(questions)
    questions.to_h do |cv|
      [ cv.id, PatientDeclaration.new(answer: params.dig(:answers, cv.id.to_s), declined: declined?(cv)) ]
    end
  end

  def declined?(cv)
    ActiveModel::Type::Boolean.new.cast(params.dig(:declined, cv.id.to_s)) || false
  end

  # One declaration per answered question, superseding any previous live answer
  # (append-only testimony). Unanswered questions are simply skipped — the form
  # says "fill in what you can". Only the questions of the page submitted: an
  # answer posted for any other rule is ignored.
  def save_declarations!(questions)
    questions.each do |cv|
      raw = params.dig(:answers, cv.id.to_s)
      declined = declined?(cv)
      next if raw.blank? && !declined

      @patient.patient_declarations.live.where(criteria_variable: cv).find_each(&:supersede!)
      @patient.patient_declarations.create!(
        criteria_variable: cv,
        prompt: cv.patient_prompt,
        answer: declined ? nil : raw.to_s,
        declined: declined,
        value_type: cv.value_type,
        qualitative_scale: cv.qualitative_scale,
        capture_mode: "public_form",
        declared_at: Time.current
      )
    end
  end

  # Server-side attach from a plain multipart form — the Active Storage
  # direct-upload endpoint stays login-gated; this never touches it. Count and
  # size caps are validated on the model.
  def attach_files!
    files = Array(params[:files]).reject(&:blank?)
    return if files.empty?

    @patient.self_reported_files.attach(files)
  end

  def update_patient_extras!
    city = params[:reported_city].to_s.strip
    if city.present? && (Patient::PRINCIPAL_CITIES.include?(city) || city == "Otra")
      @patient.reported_city = city
    end
  end

  def future_studies_authorized?
    ActiveModel::Type::Boolean.new.cast(params[:future_studies_authorization])
  end

  # Put the patient where their new answers say they belong — in practice
  # interested → candidate, when the declarations satisfy every basic
  # criterion. Attributed truthfully to the system, not to a person.
  #
  # Patient#sync_state_with_criteria! is the single implementation, shared with
  # the rep's assessment form, so there is one answer to "what do the criteria
  # say" rather than one per entry point. It cannot over-promote from here: the
  # step into `potential` is never automatic, and its guard reads investigator
  # values, which a questionnaire does not produce.
  def auto_triage!
    @patient.sync_state_with_criteria!
  end
end
