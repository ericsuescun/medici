# == Schema Information
#
# Table name: consents
#
#  id               :bigint           not null, primary key
#  document_type    :string           not null
#  document_version :string           not null
#  granted_at       :datetime         not null
#  ip_address       :string
#  purpose          :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  patient_id       :bigint           not null
#
# Indexes
#
#  index_consents_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
# An immutable record that a user granted a specific, versioned authorization —
# the Ley 1581 de 2012 habeas-data authorization to process sensitive health data,
# captured as a discrete, auditable step at registration (not folded into a
# generic terms-of-service acceptance).
class Consent < ApplicationRecord
  # Document types.
  LEY_1581_HABEAS_DATA = "ley_1581_habeas_data".freeze
  LEY_1581_CROSS_BORDER = "ley_1581_cross_border_transfer".freeze

  # Bump when the authorization text changes; the accepted version is stored per
  # record so we always know exactly what a patient agreed to.
  # 2026-07-13.1: added the "processors possibly abroad (transmisión)" acknowledgment.
  LEY_1581_CURRENT_VERSION = "2026-07-13.1".freeze

  # Processing purposes.
  PURPOSE_SENSITIVE_HEALTH = "sensitive_health_data_processing".freeze
  PURPOSE_CROSS_BORDER_TRANSFER = "cross_border_transfer_to_foreign_sponsor".freeze

  has_paper_trail

  # The authorization belongs to the person it is about. It used to hang off User
  # because it was captured during Devise sign-up; patients have no accounts now,
  # and every consent ever written was a patient's habeas-data authorization.
  belongs_to :patient

  validates :document_type, :document_version, :purpose, :granted_at, presence: true

  # Record the Ley 1581 sensitive-health-data authorization for a patient.
  def self.record_ley_1581!(patient, ip_address: nil)
    create!(
      patient: patient,
      document_type: LEY_1581_HABEAS_DATA,
      document_version: LEY_1581_CURRENT_VERSION,
      purpose: PURPOSE_SENSITIVE_HEALTH,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end

  # Record the Ley 1581 Art. 26 authorization to transfer data to a foreign
  # sponsor. Only applicable when the study's sponsor is international.
  def self.record_cross_border_transfer!(patient, ip_address: nil)
    create!(
      patient: patient,
      document_type: LEY_1581_CROSS_BORDER,
      document_version: LEY_1581_CURRENT_VERSION,
      purpose: PURPOSE_CROSS_BORDER_TRANSFER,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end

  # ---- Self-report questionnaire (added 2026-08-01) ------------------------
  # Each is deliberately its OWN document type and version constant: bumping the
  # shared LEY_1581_CURRENT_VERSION would falsely imply every existing patient
  # agreed to these newer finalidades.

  # The health questionnaire itself. Recorded when the patient submits answers
  # through the public step-2 form — the page states the purpose and the
  # submission is the authorization (Decreto 1377 Art. 7 accepts conductas
  # inequívocas; Art. 8 requires keeping proof, which this row is).
  SELF_REPORT_QUESTIONNAIRE = "ley_1581_self_report_questionnaire".freeze
  SELF_REPORT_CURRENT_VERSION = "2026-08-01.1".freeze
  PURPOSE_SELF_REPORT = "self_reported_eligibility_questionnaire".freeze

  # The OPTIONAL "consider me for other studies in the future" checkbox —
  # separate and never bundled with participation (Decreto 1377 Art. 6:
  # participation cannot be conditioned on it).
  FUTURE_STUDIES = "future_studies_matching".freeze
  FUTURE_STUDIES_CURRENT_VERSION = "2026-08-01.1".freeze
  PURPOSE_FUTURE_STUDIES = "future_studies_matching".freeze

  def self.record_self_report!(patient, ip_address: nil)
    create!(
      patient: patient,
      document_type: SELF_REPORT_QUESTIONNAIRE,
      document_version: SELF_REPORT_CURRENT_VERSION,
      purpose: PURPOSE_SELF_REPORT,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end

  def self.record_future_studies!(patient, ip_address: nil)
    create!(
      patient: patient,
      document_type: FUTURE_STUDIES,
      document_version: FUTURE_STUDIES_CURRENT_VERSION,
      purpose: PURPOSE_FUTURE_STUDIES,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end
end
