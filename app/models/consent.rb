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
#  user_id          :bigint           not null
#
# Indexes
#
#  index_consents_on_user_id                    (user_id)
#  index_consents_on_user_id_and_document_type  (user_id,document_type)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
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

  belongs_to :user

  validates :document_type, :document_version, :purpose, :granted_at, presence: true

  # Record the Ley 1581 sensitive-health-data authorization for a user.
  def self.record_ley_1581!(user, ip_address: nil)
    create!(
      user: user,
      document_type: LEY_1581_HABEAS_DATA,
      document_version: LEY_1581_CURRENT_VERSION,
      purpose: PURPOSE_SENSITIVE_HEALTH,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end

  # Record the Ley 1581 Art. 26 authorization to transfer data to a foreign
  # sponsor. Only applicable when the study's sponsor is international.
  def self.record_cross_border_transfer!(user, ip_address: nil)
    create!(
      user: user,
      document_type: LEY_1581_CROSS_BORDER,
      document_version: LEY_1581_CURRENT_VERSION,
      purpose: PURPOSE_CROSS_BORDER_TRANSFER,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end
end
