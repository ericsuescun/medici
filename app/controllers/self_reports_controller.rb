# Step 2 of the public participation flow: right after leaving contact details
# (and granting the Ley 1581 authorization), the patient answers as many of the
# study's patient-language questions as they can, in the SAME browser session.
#
# No account, no token, no link — the identity is the session: step 1 stamps
# the freshly-created patient's id into the (encrypted) session with an expiry,
# and this controller only ever reads it from there, never from params, so
# there is nothing to enumerate or forward. Inherits ApplicationController
# (public), like ParticipationRequestsController.
#
# What the patient sees is ONLY each rule's patient_prompt — never the rule
# name, thresholds or rule_summary (those describe the protocol). What they
# submit lands in patient_declarations (testimony), NEVER variable_values (the
# investigator-verified gate inputs). If the declarations satisfy every primary
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
#     not even say WHICH of the two happened.
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

  before_action :set_patient_from_session
  before_action :set_study_and_questions

  def show
    @declarations_by_variable = @patient.patient_declarations.live.index_by(&:criteria_variable_id)
  end

  private

  # The primary EXCLUSIONS, shown before any question is answered. Only
  # exclusions: those are the ones that keep somebody out of a trial that could
  # harm them, and they are the ones a person can check against themselves
  # without a clinic. Inclusions stay unlisted — "you must be 18 to 75" is a
  # threshold, and thresholds are protocol.
  def upfront_exclusions
    @questions.select { |cv| cv.variable_type == "exclusion" }
  end
  helper_method :upfront_exclusions

  public

  def create
    save_declarations!
    attach_files!
    update_patient_extras!

    unless @patient.valid?
      @declarations_by_variable = @patient.patient_declarations.live.index_by(&:criteria_variable_id)
      render :show, status: :unprocessable_entity and return
    end

    @patient.save!
    # The submission is the authorization for processing what it contains
    # (Decreto 1377 Art. 7 conductas inequívocas; the page states the purpose).
    Consent.record_self_report!(@patient, ip_address: request.remote_ip)
    # The future-studies authorization is separate and OPTIONAL — participation
    # is never conditioned on it (Decreto 1377 Art. 6).
    if future_studies_authorized?
      Consent.record_future_studies!(@patient, ip_address: request.remote_ip)
    end

    auto_triage!

    # Read AFTER auto_triage! so it reflects the same evaluation the guard used.
    # `primary_criteria_met_by_self_report?` is false both for "measurably does
    # not qualify" and for "did not answer enough", which is deliberate: the
    # patient is told the study is not a match without being told why, and
    # without the two cases being distinguishable from outside.
    looks_like_a_match = @patient.reload.primary_criteria_met_by_self_report?

    session.delete(SESSION_KEY)
    redirect_to study_about_path(@study),
                notice: t(looks_like_a_match ? "self_reports.thanks" : "self_reports.not_a_match")
  end

  private

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

    @questions = @study.criteria_profile&.criteria_variables&.askable_to_patient
                       &.sort_by { |cv| cv.criteria_order || 0 } || []
    expire! if @questions.empty?
  end

  def expire!
    session.delete(SESSION_KEY)
    redirect_to root_path
  end

  # One declaration per answered question, superseding any previous live answer
  # (append-only testimony). Unanswered questions are simply skipped — the form
  # says "fill in what you can".
  def save_declarations!
    @questions.each do |cv|
      raw = params.dig(:answers, cv.id.to_s)
      declined = ActiveModel::Type::Boolean.new.cast(params.dig(:declined, cv.id.to_s)) || false
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

  # If the declarations satisfy every primary criterion, promote interested →
  # candidate NOW, attributed truthfully to the system, not to a person. The
  # AASM guard re-checks the evidence (primary_criteria_met_for_triage?), so
  # this cannot promote anyone the rules wouldn't.
  def auto_triage!
    return unless @patient.interested?

    @patient.reload
    return unless @patient.primary_criteria_met_by_self_report?

    PaperTrail.request(whodunnit: "system:self-report-triage") do
      @patient.assess! if @patient.may_assess?
    end
  end
end
