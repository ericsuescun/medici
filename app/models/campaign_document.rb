# == Schema Information
#
# Table name: campaign_documents
#
#  id            :bigint           not null, primary key
#  document_type :string           default("file"), not null
#  external_url  :string
#  title         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  campaign_id   :bigint           not null
#
# Indexes
#
#  index_campaign_documents_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class CampaignDocument < ApplicationRecord
  has_paper_trail

  belongs_to :campaign
  has_one_attached :file

  FILE = "file".freeze
  EXTERNAL_LINK = "external_link".freeze
  DOCUMENT_TYPES = [ FILE, EXTERNAL_LINK ].freeze

  # Uploadable asset formats: PDF, MS Office, Apple iWork, and common web images.
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.apple.pages
    application/vnd.apple.numbers
    application/vnd.apple.keynote
    application/x-iwork-pages-sffpages
    application/x-iwork-numbers-sffnumbers
    application/x-iwork-keynote-sffkey
    image/jpeg
    image/png
    image/gif
    image/webp
    image/heic
    image/heif
    image/tiff
    image/bmp
  ].freeze
  # NOTE: image/svg+xml is deliberately excluded — SVG can embed scripts, and the
  # library only needs raster/document formats. Re-add only with sanitization +
  # forced-attachment serving.

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :file_or_url_present
  validate :acceptable_upload

  def external_link?
    document_type == EXTERNAL_LINK
  end

  def uploaded_file?
    document_type == FILE
  end

  # A human label for the document regardless of its kind.
  def display_name
    return title if title.present?
    return file.filename.to_s if uploaded_file? && file.attached?

    external_url
  end

  private

  def file_or_url_present
    if external_link?
      errors.add(:external_url, :blank) if external_url.blank?
    elsif !file.attached?
      errors.add(:file, :blank)
    end
  end

  # Validate the content type whenever a file is attached — independent of
  # document_type — so an external_link document can't smuggle in a disallowed
  # file past the allow-list.
  def acceptable_upload
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, :invalid_content_type)
  end
end
