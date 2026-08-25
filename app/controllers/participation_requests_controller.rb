# Public "¡Quiero participar!" flow.
#
# This deliberately does NOT create an account. A prospective patient leaves a
# way to be contacted and which study they are interested in; a trial centre rep
# calls them back and builds the real clinical record via PatientsController.
# (It replaces the old Devise sign-up, where expressing interest in a trial also
# minted a User with a password the patient never needed.)
#
# Inherits ApplicationController, not SecureApplicationController: the whole point
# is that it is reachable by someone with no account.
class ParticipationRequestsController < ApplicationController
  before_action :set_study

  def new
    @patient = Patient.new(study: @study)
  end

  # Ley 1581 de 2012 (Art. 6, 9): leaving a phone number against a *named
  # clinical trial* says something about your health, so it is sensitive personal
  # data and needs explicit, prior authorization. Same hard gate the old sign-up
  # had — without authorization nothing is written at all.
  def create
    @patient = Patient.new(participation_params.merge(study: @study))

    unless data_processing_authorized?
      @patient.errors.add(:base, t("participation_requests.authorization_required"))
      render :new, status: :unprocessable_entity and return
    end

    unless adult_confirmed?
      @patient.errors.add(:base, t("participation_requests.adult_confirmation_required"))
      render :new, status: :unprocessable_entity and return
    end

    if @patient.save
      Consent.record_ley_1581!(@patient, ip_address: request.remote_ip)
      # A foreign sponsor means the same authorization also covers the Art. 26
      # cross-border transfer — recorded distinctly so we know what was agreed.
      Consent.record_cross_border_transfer!(@patient, ip_address: request.remote_ip) if @study.international_sponsor?

      if step_two_available?
        # Stamp the questionnaire session: SelfReportsController reads the
        # patient from here (never from params), for a limited time.
        session[SelfReportsController::SESSION_KEY] = {
          "patient_id" => @patient.id,
          "expires_at" => SelfReportsController::SESSION_TTL.from_now.iso8601
        }
        redirect_to study_self_report_path(@study)
      else
        redirect_to study_about_path(@study), notice: t("participation_requests.thanks")
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_study
    @study = Study.find(params[:study_id])
  end

  # Only the contact details plus two declared facts about the submission
  # itself. Nothing clinical is collected here — that is step 2 (the
  # questionnaire) or the rep's call.
  def participation_params
    params.require(:patient).permit(:contact_number, :email, :submitted_by_proxy, :adult_confirmed)
  end

  def data_processing_authorized?
    ActiveModel::Type::Boolean.new.cast(params.dig(:patient, :data_processing_authorization))
  end

  # Ley 1581 Art. 7 proscribes processing minors' data, so the submitter must
  # assert the patient is an adult before anything is written. An assertion,
  # not a verification — recorded on the row as exactly that.
  def adult_confirmed?
    ActiveModel::Type::Boolean.new.cast(params.dig(:patient, :adult_confirmed))
  end

  # Step 2 exists only when the study has approved patient-facing questions.
  def step_two_available?
    @study.patient_self_report_enabled? &&
      @study.criteria_profile&.criteria_variables&.askable_to_patient&.exists?
  end
end
