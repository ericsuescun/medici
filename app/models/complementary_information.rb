# == Schema Information
#
# Table name: complementary_informations
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  patient_id :bigint           not null
#
# Indexes
#
#  index_complementary_informations_on_patient_id  (patient_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
# Complementary information a patient contributes about their prior care —
# previous exams as PDFs, pictures, and free written notes. One bundle per
# patient. Files are Active Storage attachments (S3 in production); the notes
# are Action Text rich text. Patients have no accounts, so in practice a rep or
# admin captures this on the patient's behalf; access is gated by the patient's
# visibility (see ComplementaryInformationsController).
class ComplementaryInformation < ApplicationRecord
  # Audit trail: this is clinical-adjacent data about an identifiable patient.
  has_paper_trail

  belongs_to :patient

  has_rich_text :notes

  # Previous exams. PDFs and images are kept as separate collections so the UI
  # can present documents and pictures differently.
  has_many_attached :documents
  has_many_attached :images

  ALLOWED_DOCUMENT_TYPES = %w[application/pdf].freeze
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/gif image/webp image/heic].freeze
  MAX_FILE_SIZE = 25.megabytes

  validate :documents_are_pdfs
  validate :images_are_images
  validate :attachments_within_size_limit

  def any_content?
    notes.present? || documents.attached? || images.attached?
  end

  private

  def documents_are_pdfs
    documents.each do |doc|
      next if ALLOWED_DOCUMENT_TYPES.include?(doc.blob.content_type)

      errors.add(:documents, I18n.t("complementary_informations.errors.not_a_pdf", filename: doc.blob.filename))
    end
  end

  def images_are_images
    images.each do |img|
      next if ALLOWED_IMAGE_TYPES.include?(img.blob.content_type)

      errors.add(:images, I18n.t("complementary_informations.errors.not_an_image", filename: img.blob.filename))
    end
  end

  def attachments_within_size_limit
    (documents + images).each do |file|
      next if file.blob.byte_size <= MAX_FILE_SIZE

      errors.add(:base, I18n.t("complementary_informations.errors.too_large", filename: file.blob.filename, limit: MAX_FILE_SIZE / 1.megabyte))
    end
  end
end
