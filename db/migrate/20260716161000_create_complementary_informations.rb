class CreateComplementaryInformations < ActiveRecord::Migration[8.0]
  # Complementary information a patient contributes about their prior care:
  # previous exams as PDFs and pictures, plus free written notes. One bundle per
  # patient (has_one). The files are Active Storage attachments (S3 in prod) and
  # the notes are Action Text rich text, so no blob/body columns live here.
  def change
    create_table :complementary_informations do |t|
      t.references :patient, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
