# == Schema Information
#
# Table name: soap_notes
#
#  id             :bigint           not null, primary key
#  encounter_date :date             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint
#  patient_id     :bigint           not null
#
# Indexes
#
#  index_soap_notes_on_author_id   (author_id)
#  index_soap_notes_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => nullify
#  fk_rails_...  (patient_id => patients.id)
#
# A SOAP note: the Subjective / Objective / Assessment / Plan format that is the
# de-facto standard for clinical-encounter documentation in US healthcare (see
# Lawrence Weed's Problem-Oriented Medical Record; NIH/StatPearls "SOAP Notes").
#
#   Subjective — what the patient reports: symptoms, history, complaints.
#   Objective  — measurable findings: vitals, exam, labs, imaging.
#   Assessment — the clinician's synthesis / diagnosis / impression.
#   Plan       — treatment, medication, follow-up, referrals, education.
#
# Each section is Action Text rich text, so images pasted/dropped into a field
# upload straight to the Active Storage service (S3 in production) as an
# attachment — the note body keeps only a reference, never the image bytes.
class SoapNote < ApplicationRecord
  # Clinical record: audit who created/edited it and when. The rich-text bodies
  # live in action_text_rich_texts (their own table); PaperTrail here tracks the
  # note's metadata and, via whodunnit, the acting user on every change.
  has_paper_trail

  belongs_to :patient
  # The clinician/rep who authored the note. Optional so deleting a staff user
  # nullifies the reference rather than destroying the clinical record.
  belongs_to :author, class_name: "User", optional: true

  # store_if_blank: false destroys the RichText row when a section is set to
  # "" or nil, releasing its embedded images to the unattached-blob sweep.
  # NOTE the browser path differs: Trix submits a cleared editor as
  # "<div><br></div>" (present), so the row survives — there the embed
  # re-sync in RichText#before_save detaches the images instead. Both paths
  # end with the blobs unattached; neither may be weakened without the other.
  has_rich_text :subjective, store_if_blank: false
  has_rich_text :objective, store_if_blank: false
  has_rich_text :assessment, store_if_blank: false
  has_rich_text :plan, store_if_blank: false

  validates :encounter_date, presence: true
  # A note with all four sections empty carries no clinical information.
  validate :at_least_one_section_present

  scope :recent, -> { order(encounter_date: :desc, created_at: :desc) }

  SECTIONS = %i[subjective objective assessment plan].freeze

  # True when the given section has any rich-text content. Reads the
  # association directly: the `subjective`-style getter auto-builds a blank
  # RichText, which autosave would then persist as an empty row for every
  # section this predicate touches during validation.
  def section_present?(section)
    public_send("rich_text_#{section}").present?
  end

  private

  def at_least_one_section_present
    return if SECTIONS.any? { |s| section_present?(s) }

    errors.add(:base, I18n.t("soap_notes.blank_note"))
  end
end
