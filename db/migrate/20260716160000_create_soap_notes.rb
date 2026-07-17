class CreateSoapNotes < ActiveRecord::Migration[8.0]
  # A SOAP note (Subjective / Objective / Assessment / Plan) — the standard
  # clinical-encounter documentation format in US healthcare, theorized by
  # Lawrence Weed as part of the Problem-Oriented Medical Record. A patient
  # accumulates as many as the research produces; the four sections themselves
  # are Action Text rich text (stored in action_text_rich_texts), so no body
  # columns live here — only the encounter metadata.
  def change
    create_table :soap_notes do |t|
      t.references :patient, null: false, foreign_key: true
      # The clinician/rep who authored the note. Nullable so a deleted author
      # doesn't cascade-destroy the clinical record.
      t.references :author, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.date :encounter_date, null: false

      t.timestamps
    end
  end
end
